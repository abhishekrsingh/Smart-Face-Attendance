import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../attendance/presentation/screens/history_screen.dart';
import '../../../leave/data/leave_repository.dart';
import '../../../leave/presentation/pages/leave_page.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // ── Bottom nav ─────────────────────────────────────────────
  int _currentIndex = 0;

  // ── Dashboard state ────────────────────────────────────────
  String? _todayStatus;
  String? _checkOutTime;
  bool _isLate = false;
  double? _totalHours;
  bool _isLoading = false;
  bool _isChecking = true;

  // ── Profile fields ─────────────────────────────────────────
  String? _profileName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayStatus());
  }

  // ── _loadTodayStatus() ────────────────────────────────────
  Future<void> _loadTodayStatus() async {
    try {
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

          // WHY avatar_url: matches ProfileRepository.getProfile()
          //   select — key names are snake_case from Supabase
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

  // ── _markAbsent() ─────────────────────────────────────────
  Future<void> _markAbsent() async {
    setState(() => _isLoading = true);

    final today = DateTime.now();
    bool hasApproval = false;
    bool checkFailed = false;

    try {
      hasApproval = await leaveRepository.checkApprovedLeaveForDate(today);
    } catch (_) {
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
            'You need admin approval before marking yourself '
            'absent.\n\nApply for leave → wait for admin to '
            'approve → then mark absent.',
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
                // ── Switch to Leave tab instead of Navigator.push
                // WHY: Leave is already tab index 2 — no new
                //   route needed, avoids double back stack
                setState(() => _currentIndex = 2);
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
          'Are you sure you want to mark yourself absent '
          'for today?\n\nThis cannot be undone without admin.',
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

  // ── _buildDashboard() ────────────────────────────────────
  Widget _buildDashboard() {
    final attState = _attendanceState;
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: _loadTodayStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _isChecking
            ? const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Avatar ──────────────────────────────
                  _HomeAvatar(
                    avatarUrl: _avatarUrl,
                    name: _profileName ?? '',
                    primaryColor: primary,
                  ),
                  const SizedBox(height: 16),

                  // ── Welcome text ────────────────────────
                  Text(
                    'Welcome,',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profileName ?? 'Employee',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Today status card ───────────────────
                  if (_todayStatus != null) ...[
                    _TodayStatusCard(
                      status: _todayStatus!,
                      checkOutTime: _checkOutTime,
                      isLate: _isLate,
                      totalHours: _totalHours,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Register Face ───────────────────────
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.faceRegister),
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: const Text('Register Face'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Check In / Out / Re-Check ───────────
                  if (attState != _AttendanceState.absent)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await context.push(AppRoutes.markAttendance);
                        _loadTodayStatus();
                      },
                      icon: Icon(_attendanceIcon(attState)),
                      label: Text(_attendanceLabel(attState)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _attendanceColor(attState),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),

                  // ── Mark Absent ─────────────────────────
                  if (attState == _AttendanceState.noRecord) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
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
                  ],

                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  // ── build() ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // WHY IndexedStack: keeps all tab states alive —
    //   no re-fetch when switching between tabs
    final pages = [
      _buildDashboard(), // 0 — Home
      const HistoryScreen(), // 1 — History
      const LeavePage(), // 2 — Leave
      const ProfilePage(), // 3 — Profile
    ];

    return Scaffold(
      // WHY null on profile tab: ProfilePage has its own
      //   AppBar with refresh + edit actions — showing two
      //   AppBars stacked looks broken and wastes space
      appBar: _currentIndex == 3
          ? null
          : AppBar(
              title: Text(_appBarTitle(_currentIndex)),
              centerTitle: true,
              actions: [
                if (_currentIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        useRootNavigator: true,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(
                                ctx,
                                rootNavigator: true,
                              ).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(
                                ctx,
                                rootNavigator: true,
                              ).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await Supabase.instance.client.auth.signOut();
                      }
                    },
                  ),
              ],
            ),

      body: IndexedStack(index: _currentIndex, children: pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Leave',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _appBarTitle(int i) => switch (i) {
    0 => 'Dashboard',
    1 => 'History',
    2 => 'My Leaves',
    _ => 'FaceAttend',
  };

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
// WHY shows initial letter when no avatar: this is correct
//   fallback behavior — "A" for Abhishek is intentional
//   until an avatar photo is uploaded in Profile tab
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
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: primaryColor.withValues(alpha: 0.1),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                if (isLate && status != 'absent') ...[
                  const SizedBox(height: 4),
                  Container(
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
                ],
                if (totalHours != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🕐 ${totalHours!.toStringAsFixed(1)}h worked',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (checkOutTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Checked out ✓',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
