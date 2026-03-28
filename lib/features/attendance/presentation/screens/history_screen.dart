// ============================================================
// HistoryScreen
// PURPOSE: Displays last 7 days of attendance as a scrollable
// card list. Each card shows date, status, check-in/out times,
// late badge, and total hours worked.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';
import '../../data/models/attendance_model.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // WHY microtask: Calling provider inside initState directly can
    // cause "setState during build" error — microtask defers safely
    Future.microtask(() => ref.read(historyProvider.notifier).loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    // Watch state — rebuilds automatically when state changes
    final state = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          // Manual refresh button in top-right
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(historyProvider.notifier).loadHistory(),
          ),
        ],
      ),

      body: Builder(
        builder: (_) {
          // ── State 1: Loading ──────────────────────────────────
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── State 2: Error ────────────────────────────────────
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(historyProvider.notifier).loadHistory(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // ── State 3: Empty ────────────────────────────────────
          if (state.records.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No attendance records found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // ── State 4: Records loaded — show list ───────────────
          // RefreshIndicator = pull-to-refresh gesture support
          return RefreshIndicator(
            onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.records.length,
              // Adds gap between cards without putting it inside itemBuilder
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) =>
                  _AttendanceCard(record: state.records[i]),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// _AttendanceCard
// PURPOSE: Single row card showing one day's attendance info —
// date badge, status chip, late chip, times, total hours.
// ============================================================
class _AttendanceCard extends StatelessWidget {
  final AttendanceModel record;
  const _AttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: Date Badge ─────────────────────────────
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                // WHY withValues: withOpacity() deprecated in Flutter 3.27+
                // withValues(alpha:) is the replacement — no precision loss
                color: _statusColor(record.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    _dayNum(record.date), // e.g. "25"
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(record.status),
                    ),
                  ),
                  Text(
                    _monthShort(record.date), // e.g. "Mar"
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(record.status),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── Right: Details ───────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Status chip + optional Late chip
                  Row(
                    children: [
                      _StatusChip(status: record.status),
                      if (record.isLate) ...[
                        const SizedBox(width: 6),
                        const _LateChip(),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Check-in and Check-out times with icons
                  Row(
                    children: [
                      const Icon(Icons.login, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'In: ${_formatTime(record.checkInTime)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.logout, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Out: ${_formatTime(record.checkOutTime)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),

                  // Row 3: Total hours — only visible after check-out
                  if (record.totalHours != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⏱ ${record.totalHours!.toStringAsFixed(1)} hrs',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  // Convert UTC ISO string → local IST time string "HH:mm"
  // WHY .toLocal(): timestamps saved as UTC "Z" → +5:30 = IST display
  String _formatTime(String? iso) {
    if (iso == null) return '--:--';
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  // Extract day from "2026-03-25" → "25"
  String _dayNum(String date) => date.split('-')[2];

  // Extract month name from "2026-03-25" → "Mar"
  String _monthShort(String date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[int.parse(date.split('-')[1])];
  }

  // Map status string → display color used in badge + chips
  Color _statusColor(String status) => switch (status) {
    'Present' => Colors.green,
    'Absent' => Colors.red,
    'Half Day' => Colors.orange,
    'WFH' => Colors.blue,
    _ => Colors.grey,
  };
}

// ============================================================
// _StatusChip
// PURPOSE: Colored pill badge showing attendance status text.
// ============================================================
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Present' => Colors.green,
      'Absent' => Colors.red,
      'Half Day' => Colors.orange,
      'WFH' => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // WHY withValues: replacement for deprecated withOpacity()
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// _LateChip
// PURPOSE: Orange pill badge — only shown when isLate = true.
// ============================================================
class _LateChip extends StatelessWidget {
  const _LateChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // WHY withValues: replacement for deprecated withOpacity()
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '⚠ Late',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.orange,
        ),
      ),
    );
  }
}
