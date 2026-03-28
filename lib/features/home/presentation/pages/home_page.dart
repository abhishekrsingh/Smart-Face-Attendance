import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../attendance/data/attendance_repository.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _todayStatus;
  String? _checkOutTime;
  // ── Feature 1: Late badge ──────────────────────────────────
  // WHY bool not null: is_late is always true/false in DB
  // default false = not late (safe fallback if DB returns null)
  bool _isLate = false;
  // ── Feature 3: Work hours ──────────────────────────────────
  // WHY nullable: only has value after checkout
  // null = not checked out yet → don't show hours
  double? _totalHours;

  bool _isLoading = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayStatus());
  }

  Future<void> _loadTodayStatus() async {
    try {
      final record = await attendanceRepository.getTodayAttendance();
      if (mounted) {
        setState(() {
          _todayStatus = record?['status'] as String?;
          _checkOutTime = record?['check_out_time'] as String?;
          // WHY ?? false: is_late may be null if no record yet
          _isLate = record?['is_late'] as bool? ?? false;
          // WHY num→double: Supabase may return int or double
          // for total_hours — (num) handles both safely
          _totalHours = (record?['total_hours'] as num?)?.toDouble();
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  _AttendanceState get _attendanceState {
    if (_todayStatus == null) return _AttendanceState.noRecord;
    if (_todayStatus == 'absent') return _AttendanceState.absent;
    if (_checkOutTime == null) return _AttendanceState.checkedIn;
    return _AttendanceState.checkedOut;
  }

  Future<void> _markAbsent() async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('Mark Absent'),
        content: const Text(
          'Are you sure you want to mark yourself absent for today?\n\n'
          'This cannot be changed without admin help.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Mark Absent'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);

    try {
      await attendanceRepository.markAbsent();
      if (mounted) {
        setState(() {
          _todayStatus = 'absent';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked absent for today'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final state = _attendanceState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async =>
                await Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Center(
        child: _isChecking
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 80,
                    color: AppColors.present,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome!',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Status Card ────────────────────────────────
                  if (_todayStatus != null) ...[
                    _TodayStatusCard(
                      status: _todayStatus!,
                      checkOutTime: _checkOutTime,
                      isLate: _isLate, // ← Feature 1
                      totalHours: _totalHours, // ← Feature 3
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Register Face ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.faceRegister),
                      icon: const Icon(Icons.face_retouching_natural_rounded),
                      label: const Text('Register Face'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Attendance Button ──────────────────────────
                  if (state != _AttendanceState.absent)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.push(AppRoutes.markAttendance);
                          _loadTodayStatus();
                        },
                        icon: Icon(_attendanceIcon(state)),
                        label: Text(_attendanceLabel(state)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _attendanceColor(state),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),

                  // ── Mark Absent ────────────────────────────────
                  if (state == _AttendanceState.noRecord) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _markAbsent,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Icon(
                                Icons.cancel_outlined,
                                color: Colors.red,
                              ),
                        label: Text(
                          _isLoading ? 'Marking...' : 'Mark Absent Today',
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _attendanceLabel(_AttendanceState state) {
    return switch (state) {
      _AttendanceState.noRecord => 'Check In',
      _AttendanceState.checkedIn => 'Check Out',
      _AttendanceState.checkedOut => 'Re-Check In',
      _AttendanceState.absent => '',
    };
  }

  IconData _attendanceIcon(_AttendanceState state) {
    return switch (state) {
      _AttendanceState.noRecord => Icons.fingerprint_rounded,
      _AttendanceState.checkedIn => Icons.logout_rounded,
      _AttendanceState.checkedOut => Icons.login_rounded,
      _AttendanceState.absent => Icons.close,
    };
  }

  Color _attendanceColor(_AttendanceState state) {
    return switch (state) {
      _AttendanceState.noRecord => AppColors.present,
      _AttendanceState.checkedIn => Colors.blue,
      _AttendanceState.checkedOut => Colors.orange,
      _AttendanceState.absent => Colors.grey,
    };
  }
}

enum _AttendanceState { noRecord, checkedIn, checkedOut, absent }

// ── _TodayStatusCard ──────────────────────────────────────────
// UPDATED: Added isLate + totalHours params
class _TodayStatusCard extends StatelessWidget {
  final String status;
  final String? checkOutTime;
  final bool isLate; // ← Feature 1
  final double? totalHours; // ← Feature 3

  const _TodayStatusCard({
    required this.status,
    this.checkOutTime,
    this.isLate = false,
    this.totalHours,
  });

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (status.toLowerCase()) {
      'present' => ('🏢', 'Work From Office', Colors.green),
      'wfh' => ('🏠', 'Work From Home', Colors.blue),
      'absent' => ('❌', 'Marked Absent', Colors.red),
      _ => ('📋', 'Attendance Marked', Colors.grey),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Status",
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // ── Feature 1: Late Badge ──────────────────────
              // WHY amber: warning color — not as severe as red
              // but clearly visible — draws attention
              if (isLate && status != 'absent')
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text(
                    '⚠️ Late Arrival',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // ── Feature 3: Work Hours ──────────────────────
              // WHY only after checkout: total_hours is null
              // until checkout — showing 0h mid-day is misleading
              if (totalHours != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🕐 Total: ${totalHours!.toStringAsFixed(1)}h worked',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // ── Checked out indicator ──────────────────────
              if (checkOutTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Checked out ✓',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
