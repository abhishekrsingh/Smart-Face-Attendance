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
  String? _checkOutTime; // ← NEW: track checkout to know button state
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
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // ── Determine button state ────────────────────────────────
  // WHY enum-like logic: 4 possible states need different UI
  //
  //  noRecord   → null status          → show CheckIn + MarkAbsent
  //  checkedIn  → status set, no cout  → show CheckOut only
  //  checkedOut → status set, cout set → show ReCheckIn only
  //  absent     → status = absent      → show nothing
  _AttendanceState get _attendanceState {
    if (_todayStatus == null) return _AttendanceState.noRecord;
    if (_todayStatus == 'absent') return _AttendanceState.absent;
    if (_checkOutTime == null) return _AttendanceState.checkedIn;
    return _AttendanceState.checkedOut;
  }

  Future<void> _markAbsent() async {
    final confirm = await showDialog<bool>(
      context: context,
      // ✅ KEY FIX: useRootNavigator: true → uses Flutter's root
      // navigator, not GoRouter's navigator — prevents GoRouter
      // from intercepting Navigator.pop() and triggering auth redirect
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('Mark Absent'),
        content: const Text(
          'Are you sure you want to mark yourself absent for today?\n\n'
          'This cannot be changed without admin help.',
        ),
        actions: [
          TextButton(
            // ✅ Navigator.of(context, rootNavigator: true).pop()
            // ensures dialog closes cleanly without touching GoRouter stack
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

                  // ── Status Card (shown if any record exists) ───
                  if (_todayStatus != null) ...[
                    _TodayStatusCard(
                      status: _todayStatus!,
                      checkOutTime: _checkOutTime,
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

                  // ── Mark Attendance Button ─────────────────────
                  // Label + color changes based on state:
                  // noRecord   → 🟢 Check In
                  // checkedIn  → 🔵 Check Out
                  // checkedOut → 🟠 Re-Check In
                  // absent     → hidden
                  if (state != _AttendanceState.absent)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.push(AppRoutes.markAttendance);
                          // WHY reload: status may have changed after
                          // returning from attendance screen
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

                  // ── Mark Absent (only when no record yet) ──────
                  // WHY only noRecord: can't mark absent if
                  // already checked in or done
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

  // ── Button helpers ─────────────────────────────────────────
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
      _AttendanceState.noRecord => AppColors.present, // green
      _AttendanceState.checkedIn => Colors.blue, // blue
      _AttendanceState.checkedOut => Colors.orange, // orange
      _AttendanceState.absent => Colors.grey,
    };
  }
}

// ── Attendance State Enum ─────────────────────────────────────
// WHY enum: 4 clearly named states — much cleaner than
// multiple bool flags like isCheckedIn, isCheckedOut, etc.
enum _AttendanceState { noRecord, checkedIn, checkedOut, absent }

// ── _TodayStatusCard ──────────────────────────────────────────
class _TodayStatusCard extends StatelessWidget {
  final String status;
  final String? checkOutTime; // ← shows check-out time if done

  const _TodayStatusCard({required this.status, this.checkOutTime});

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
              // WHY show checkout time: employee sees when they left
              if (checkOutTime != null)
                Text(
                  'Checked out ✓',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
