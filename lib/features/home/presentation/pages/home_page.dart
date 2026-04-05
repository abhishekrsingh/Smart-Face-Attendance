// ============================================================
// home_page.dart
// PURPOSE : Root screen of the app — bottom nav with 4 tabs:
//           Dashboard, History, Leave, Profile.
//           Also owns the weekend holiday dialog + view since
//           the dashboard (tab 0) is built directly here via
//           _buildDashboard(), not via AttendanceScreen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/date_helper.dart'; // ← NEW
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

  // ── Weekend holiday flag ───────────────────────────────────
  // WHY here: dashboard is _buildDashboard() inside HomePage,
  //   not AttendanceScreen, so holiday state must live here.
  // true  = employee chose "I'm working today" on dialog
  // false = employee is on holiday (show _HolidayView)
  bool _workingOnWeekend = false;

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

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // WHY postFrameCallback: context is fully ready after first
    //   frame — both showDialog and Supabase calls need it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayStatus();
      // Show holiday dialog only on Saturday / Sunday
      if (DateHelper.isTodayWeekend) {
        _showHolidayDialog();
      }
    });
  }

  // ── _showHolidayDialog() ───────────────────────────────────
  // WHY useRootNavigator: true — app uses IndexedStack inside
  //   a Scaffold, so the local navigator context is the shell.
  //   Without this, the dialog is swallowed by the shell and
  //   never renders. useRootNavigator pushes it to the top
  //   MaterialApp navigator, above everything.
  Future<void> _showHolidayDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // force a conscious choice
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _HolidayDialog(date: DateTime.now()),
    );
    // result = true  → "I'm working today" was tapped
    // result = false → "Got it, enjoy holiday!" was tapped
    if (mounted) {
      setState(() => _workingOnWeekend = result ?? false);
    }
  }

  // ── _loadTodayStatus() ─────────────────────────────────────
  Future<void> _loadTodayStatus() async {
    try {
      final results = await Future.wait([
        attendanceRepository.getTodayAttendance(),
        profileRepository.getProfile(),
      ]);

      final record = results[0];
      final profile = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _todayStatus = record?['status'] as String?;
          _checkOutTime = record?['check_out_time'] as String?;
          _isLate = record?['is_late'] as bool? ?? false;
          _totalHours = (record?['total_hours'] as num?)?.toDouble();

          // WHY snake_case: matches Supabase column names returned
          //   by ProfileRepository.getProfile() select query
          _profileName = profile['full_name'] as String?;
          _avatarUrl = profile['avatar_url'] as String?;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // ── Attendance state helper ────────────────────────────────
  _AttendanceState get _attendanceState {
    if (_todayStatus == null) return _AttendanceState.noRecord;
    if (_todayStatus == 'absent') return _AttendanceState.absent;
    if (_checkOutTime == null) return _AttendanceState.checkedIn;
    return _AttendanceState.checkedOut;
  }

  // ── _markAbsent() ──────────────────────────────────────────
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

    // ── System error — couldn't verify leave status ──────────
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

    // ── No approved leave — block absent marking ─────────────
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
                // WHY setState index 2: Leave tab is already
                //   mounted in IndexedStack — no new route
                //   needed, avoids extra back-stack entry
                setState(() => _currentIndex = 2);
              },
            ),
          ],
        ),
      );
      return;
    }

    // ── Confirmed + approved — mark absent ───────────────────
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

  // ── _buildDashboard() ──────────────────────────────────────
  Widget _buildDashboard() {
    // ── Weekend holiday view ─────────────────────────────────
    // WHY check here: IndexedStack keeps this widget alive even
    //   when another tab is active — the check is cheap and
    //   ensures holiday view persists until user taps "Undo"
    if (DateHelper.isTodayWeekend && !_workingOnWeekend) {
      return _HolidayView(
        date: DateTime.now(),
        // Tapping "I need to check in anyway" re-shows dashboard
        onWorkAnyway: () => setState(() => _workingOnWeekend = true),
      );
    }

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
                  // ── Weekend working banner ──────────────
                  // Shown when employee dismissed holiday
                  // and chose to work — has Undo option
                  if (DateHelper.isTodayWeekend && _workingOnWeekend) ...[
                    _WeekendWorkingBanner(
                      date: DateTime.now(),
                      onUndoTap: () =>
                          setState(() => _workingOnWeekend = false),
                    ),
                    const SizedBox(height: 12),
                  ],

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

                  // ── Check In / Out / Re-Check In ────────
                  // Hidden when absent — no need to check in
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
                  // Only shown when no record yet for today
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

  // ── build() ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // WHY IndexedStack: keeps all tab states alive so switching
    //   tabs does not re-fetch data or reset scroll position
    final pages = [
      _buildDashboard(), // 0 — Home / Dashboard
      const HistoryScreen(), // 1 — Attendance history
      const LeavePage(), // 2 — Leave management
      const ProfilePage(), // 3 — Profile + settings
    ];

    return Scaffold(
      // WHY null on profile tab: ProfilePage has its own AppBar
      //   with refresh + edit actions — two stacked AppBars
      //   would look broken and waste vertical space
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

  // ── Helpers ────────────────────────────────────────────────
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

// ============================================================
// _HolidayDialog — animated dialog shown on Sat/Sun
// Animation: emoji bounce → text slide up → buttons fade in
// ============================================================
class _HolidayDialog extends StatefulWidget {
  final DateTime date;
  const _HolidayDialog({required this.date});

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _emojiScale;
  late final Animation<double> _emojiFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _contentFade;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Emoji: scale 0→1.2→1.0 (overshoot gives bouncy feel)
    _emojiScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_ctrl);

    _emojiFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
          ),
        );

    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    _buttonFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _dayLabel => DateHelper.weekendLabel(widget.date) ?? 'Weekend';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _emojiFade,
              child: ScaleTransition(
                scale: _emojiScale,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Text('🏖️', style: TextStyle(fontSize: 56)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: Column(
                  children: [
                    Text(
                      'Today is $_dayLabel!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "It's a holiday 🎉\nRelax and enjoy your day off.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.beach_access_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'No attendance required',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            FadeTransition(
              opacity: _buttonFade,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      // pop(false) → _workingOnWeekend = false → HolidayView
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                      icon: const Text('🎉', style: TextStyle(fontSize: 16)),
                      label: const Text('Got it, enjoy holiday!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      // pop(true) → _workingOnWeekend = true → Dashboard
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                      icon: const Text('💪', style: TextStyle(fontSize: 14)),
                      label: const Text("I'm working today"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _WeekendWorkingBanner — amber strip shown at top of
// dashboard when employee chose "I'm working today"
// ============================================================
class _WeekendWorkingBanner extends StatelessWidget {
  final DateTime date;
  final VoidCallback onUndoTap;
  const _WeekendWorkingBanner({required this.date, required this.onUndoTap});

  @override
  Widget build(BuildContext context) {
    final label = DateHelper.weekendLabel(date) ?? 'Weekend';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('💪', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Working on $label',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ),
          GestureDetector(
            onTap: onUndoTap,
            child: Text(
              'Undo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _HolidayView — full body screen shown after "Got it"
// ============================================================
class _HolidayView extends StatelessWidget {
  final DateTime date;
  final VoidCallback onWorkAnyway;
  const _HolidayView({required this.date, required this.onWorkAnyway});

  @override
  Widget build(BuildContext context) {
    final label = DateHelper.weekendLabel(date) ?? 'Weekend';
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Text('🏖️', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 28),
            Text(
              'Today is $label',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Enjoy your well-deserved day off! 🎉',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.beach_access_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'No attendance required today',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Subtle escape hatch — low contrast intentional
            TextButton.icon(
              onPressed: onWorkAnyway,
              icon: const Text('💪', style: TextStyle(fontSize: 13)),
              label: const Text('I need to check in anyway'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _HomeAvatar — avatar photo or initial letter fallback
// WHY ClipOval: tighter clip than CircleAvatar backgroundImage
// ============================================================
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

// ============================================================
// _TodayStatusCard — compact status row in dashboard
// ============================================================
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
