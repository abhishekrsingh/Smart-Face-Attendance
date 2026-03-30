import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../leave/data/leave_repository.dart';
import '../../../leave/presentation/pages/leave_page.dart';
import '../../../profile/data/profile_repository.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _todayStatus;
  String? _checkOutTime;
  bool _isLate = false;
  double? _totalHours;
  bool _isLoading = false;
  bool _isChecking = true;

  // ── Profile fields for welcome header ──────────────────────
  String? _profileName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayStatus());
  }

  Future<void> _loadTodayStatus() async {
    try {
      // ── Load attendance + profile together ─────────────────
      // WHY parallel: both are independent — no need to wait
      final results = await Future.wait([
        attendanceRepository.getTodayAttendance(),
        profileRepository.getProfile(),
      ]);

      final record = results[0] as Map<String, dynamic>?;
      final profile = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _todayStatus = record?['status'] as String?;
          _checkOutTime = record?['check_out_time'] as String?;
          _isLate = record?['is_late'] as bool? ?? false;
          _totalHours = (record?['total_hours'] as num?)?.toDouble();
          _profileName = profile['full_name'] as String?;
          _avatarUrl = profile['avatar_url'] as String?;
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

  // ── _markAbsent() ───────────────────────────────────────────
  Future<void> _markAbsent() async {
    setState(() => _isLoading = true);

    final today = DateTime.now();
    bool hasApproval = false;
    bool checkFailed = false;

    try {
      hasApproval = await leaveRepository.checkApprovedLeaveForDate(today);
    } catch (e) {
      checkFailed = true;
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (checkFailed) {
      await showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('System Error', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Could not verify leave approval status.\n\n'
            'Please contact your admin or try again later.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!hasApproval) {
      await showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Text('🔒', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('Approval Required', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'You need admin approval before marking yourself absent.\n\n'
            'Apply for leave → wait for admin to approve → '
            'then you can mark absent.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Apply for Leave'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeavePage()),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

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
    final state = _attendanceState;
    final primary = Theme.of(context).colorScheme.primary;

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
                  // ── Avatar ────────────────────────────────────
                  // WHY avatar not tick: shows the actual employee
                  // identity rather than a generic success icon
                  _HomeAvatar(
                    avatarUrl: _avatarUrl,
                    name: _profileName ?? '',
                    primaryColor: primary,
                  ),
                  const SizedBox(height: 18),

                  // ── Welcome label ─────────────────────────────
                  Text(
                    'Welcome,',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Employee name ─────────────────────────────
                  // WHY primary color + bold: name stands out as
                  // the key identity element on the dashboard
                  Text(
                    _profileName ?? 'Employee',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Status Card ──────────────────────────────
                  if (_todayStatus != null) ...[
                    _TodayStatusCard(
                      status: _todayStatus!,
                      checkOutTime: _checkOutTime,
                      isLate: _isLate,
                      totalHours: _totalHours,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Register Face ────────────────────────────
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

                  // ── Attendance Button ────────────────────────
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

                  // ── Mark Absent ──────────────────────────────
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
                          _isLoading ? 'Checking...' : 'Mark Absent',
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),
                  ],

                  // ── My Leaves ────────────────────────────────
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeavePage()),
                      ).then((_) => _loadTodayStatus()),
                      icon: const Icon(Icons.event_note_rounded),
                      label: const Text('My Leaves'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _attendanceLabel(_AttendanceState s) => switch (s) {
    _AttendanceState.noRecord => 'Check In',
    _AttendanceState.checkedIn => 'Check Out',
    _AttendanceState.checkedOut => 'Re-Check In',
    _AttendanceState.absent => '',
  };

  IconData _attendanceIcon(_AttendanceState s) => switch (s) {
    _AttendanceState.noRecord => Icons.fingerprint_rounded,
    _AttendanceState.checkedIn => Icons.logout_rounded,
    _AttendanceState.checkedOut => Icons.login_rounded,
    _AttendanceState.absent => Icons.close,
  };

  Color _attendanceColor(_AttendanceState s) => switch (s) {
    _AttendanceState.noRecord => AppColors.present,
    _AttendanceState.checkedIn => Colors.blue,
    _AttendanceState.checkedOut => Colors.orange,
    _AttendanceState.absent => Colors.grey,
  };
}

enum _AttendanceState { noRecord, checkedIn, checkedOut, absent }

// ── _HomeAvatar ───────────────────────────────────────────────
// PURPOSE: Dashboard welcome avatar — replaces the tick icon
// WHY ClipOval + BoxFit.cover: fills circle with no gap
class _HomeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final Color primaryColor;

  const _HomeAvatar({
    required this.avatarUrl,
    required this.name,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.4),
          width: 3,
        ),
        color: primaryColor.withValues(alpha: 0.08),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                width: 90,
                height: 90,
                fit: BoxFit.cover, // ← fills circle fully
                errorBuilder: (_, __, ___) => _fallback(primaryColor),
              )
            : _fallback(primaryColor),
      ),
    );
  }

  Widget _fallback(Color color) => Container(
    color: color.withValues(alpha: 0.12),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ),
  );
}

// ── _TodayStatusCard ──────────────────────────────────────────
class _TodayStatusCard extends StatelessWidget {
  final String status;
  final String? checkOutTime;
  final bool isLate;
  final double? totalHours;

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
