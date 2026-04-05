// ============================================================
// attendance_screen.dart
// PURPOSE : Shown at AppRoutes.markAttendance — lets the
//           employee Check In / Check Out using face scan.
//           Holiday logic lives in home_page.dart.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Today's status summary card ──────────────
              _TodayStatusCard(state: state),
              const SizedBox(height: 20),

              // ── Error banner (shown only on failure) ─────
              if (state.error != null)
                _Banner(
                  message: state.error!,
                  color: Colors.red,
                  icon: Icons.error_outline,
                ),

              // ── Success banner (shown after action) ──────
              if (state.successMessage != null)
                _Banner(
                  message: state.successMessage!,
                  color: Colors.green,
                  icon: Icons.check_circle_outline,
                ),

              const Spacer(),

              // ── Primary action: Check In or Check Out ────
              _ActionButton(state: state, ref: ref),
              const SizedBox(height: 12),

              // ── Secondary: browse history ────────────────
              OutlinedButton.icon(
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history),
                label: const Text('View History'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// _TodayStatusCard
// PURPOSE : Shows today's summary — status, check-in/out
//           times, total hours, late badge, WFO/WFH badge.
// ============================================================
class _TodayStatusCard extends StatelessWidget {
  final AttendanceState state;
  const _TodayStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (state.todayStatus) {
      'Present' => Colors.green,
      'WFH' => Colors.blue,
      'Half Day' => Colors.orange,
      'Absent' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayLabel(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.todayStatus ?? 'Not marked yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              _WorkModeBadge(hasCheckedIn: state.hasCheckedIn),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: statusColor.withValues(alpha: 0.2)),
          const SizedBox(height: 14),

          if (state.isLate) ...[_LateBadge(), const SizedBox(height: 10)],

          _TimeRow(
            icon: Icons.login,
            label: 'First Check-In',
            time: state.checkInTime ?? '--:--',
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _TimeRow(
            icon: Icons.logout,
            label: 'Last Check-Out',
            time: state.checkOutTime ?? '--:--',
            color: Colors.red,
          ),

          if (state.todayRecord?.totalHours != null) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: statusColor.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total Hours: '
                  '${state.todayRecord!.totalHours!.toStringAsFixed(1)} hrs',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ],

          if (state.hasCheckedIn && !state.hasCheckedOut) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: statusColor.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Currently in office',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    return '${days[now.weekday - 1]}, '
        '${now.day} ${months[now.month]} ${now.year}';
  }
}

// ============================================================
// _WorkModeBadge — WFO or WFH pill in top-right of status card
// ============================================================
class _WorkModeBadge extends StatelessWidget {
  final bool hasCheckedIn;
  const _WorkModeBadge({required this.hasCheckedIn});

  @override
  Widget build(BuildContext context) {
    final emoji = hasCheckedIn ? '🏢' : '🏠';
    final label = hasCheckedIn ? 'Work From Office' : 'Work From Home';
    final color = hasCheckedIn ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _LateBadge — amber pill shown only when isLate = true
// ============================================================
class _LateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚠️', style: TextStyle(fontSize: 13)),
          SizedBox(width: 5),
          Text(
            'Late Check-In',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _ActionButton — smart Check In / Check Out toggle
// WHY passing ref: avoids making this widget a ConsumerWidget
// ============================================================
class _ActionButton extends StatelessWidget {
  final AttendanceState state;
  final WidgetRef ref;
  const _ActionButton({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    // True when no check-in yet OR already checked out (re-check-in)
    final isCheckInAction = !state.hasCheckedIn || state.hasCheckedOut;

    final label = state.isLoading
        ? 'Processing...'
        : isCheckInAction
        ? 'Check In'
        : 'Check Out';

    final icon = isCheckInAction ? Icons.login_rounded : Icons.logout_rounded;
    final color = isCheckInAction ? Colors.green : Colors.red;

    return ElevatedButton.icon(
      onPressed: state.isLoading
          ? null
          : () => ref.read(attendanceProvider.notifier).markAttendance(),
      icon: state.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================
// _TimeRow — icon + label + time in a single row
// ============================================================
class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Text(
          time,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: time == '--:--' ? Colors.grey : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// _Banner — success / error message strip above action button
// ============================================================
class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
