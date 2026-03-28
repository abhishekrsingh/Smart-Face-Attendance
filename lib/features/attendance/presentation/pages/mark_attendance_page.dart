import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/attendance_provider.dart';
import '../widgets/recognition_overlay.dart';
import '../../../face_registration/presentation/widgets/face_overlay_painter.dart';

class MarkAttendancePage extends ConsumerStatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  ConsumerState<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends ConsumerState<MarkAttendancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late AttendanceNotifier _notifier;
  bool _dialogShown = false; // WHY: prevent duplicate dialogs

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _notifier = ref.read(attendanceProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier.initialize();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _notifier.disposeResources();
    super.dispose();
  }

  // ── _showAfterHoursDialog() ────────────────────────────────
  Future<void> _showAfterHoursDialog(String message) async {
    if (_dialogShown) return;
    _dialogShown = true;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        // WHY LayoutBuilder: makes dialog responsive to screen size
        final screenW = MediaQuery.of(ctx).size.width;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // WHY constrained width: prevents overflow on small screens
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenW * 0.08,
            vertical: 24,
          ),
          title: const Row(
            children: [
              Text('🕕', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Office Hours Ended',
                  style: TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // WHY SingleChildScrollView: long messages won't overflow
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );

    _dialogShown = false;
    if (mounted) Navigator.of(context).pop(); // pop camera page
  }

  // ── _showAutoCheckoutDialog() ──────────────────────────────
  Future<void> _showAutoCheckoutDialog(String message) async {
    if (_dialogShown) return;
    _dialogShown = true;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        final screenW = MediaQuery.of(ctx).size.width;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenW * 0.08,
            vertical: 24,
          ),
          title: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Auto Checked Out',
                  style: TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );

    _dialogShown = false;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);

    // ── Listen for state changes → dialogs + auto-pop ───────
    ref.listen<AttendanceState>(attendanceProvider, (prev, next) {
      if (prev?.status == next.status) return;

      // ── After hours → show dialog (blocks check-in/re-check-in)
      if (next.status == AttendanceStatus.afterOfficeHours) {
        _showAfterHoursDialog(
          next.message ??
              'Check-in is not allowed after 6:00 PM.\n'
                  'Office hours are 9:00 AM – 6:00 PM.',
        );
      }

      // ── Auto-checkout → show info dialog
      if (next.status == AttendanceStatus.autoCheckoutSuccess) {
        _showAutoCheckoutDialog(
          next.message ??
              'You have been automatically checked out.\n'
                  'Have a good evening! 👋',
        );
      }

      // ── Success → auto-pop after 2s ─────────────────────────
      // WHY auto-pop: prevents user staying on camera page
      // after success. If they tap screen, it would trigger
      // initialize() which re-checks 6PM condition → unwanted dialog
      if (next.status == AttendanceStatus.checkInSuccess ||
          next.status == AttendanceStatus.checkOutSuccess) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mark Attendance',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CompactStatusStrip(state: state),
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: () {
                  if (!_isResultState(state.status)) return;
                  // WHY pop on success: don't reinitialize — go home
                  // WHY reinitialize on error: let user retry
                  if (state.status == AttendanceStatus.checkInSuccess ||
                      state.status == AttendanceStatus.checkOutSuccess ||
                      state.status == AttendanceStatus.autoCheckoutSuccess) {
                    Navigator.of(context).pop();
                  } else {
                    _notifier.initialize();
                  }
                },
                child: Stack(
                  children: [
                    _buildCamera(state),
                    RecognitionOverlay(
                      status: state.status,
                      message: state.message,
                      confidence: state.confidence,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 1, child: _buildControls(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera(AttendanceState state) {
    final controller = _notifier.cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Initializing...',
              style: TextStyle(color: Colors.white60, fontFamily: 'Poppins'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _scanController,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(child: CameraPreview(controller)),
          CustomPaint(
            painter: FaceOverlayPainter(
              faceDetected:
                  state.status == AttendanceStatus.checkInSuccess ||
                  state.status == AttendanceStatus.checkOutSuccess ||
                  state.status == AttendanceStatus.autoCheckoutSuccess,
              animationValue: _scanController.value,
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(bottom: 16, child: _buildStatusChip(state)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AttendanceState state) {
    final isCheckInAction = !state.hasCheckedIn || state.hasCheckedOut;
    String msg = isCheckInAction ? 'Ready to check in' : 'Ready to check out';
    Color color = Colors.white70;

    switch (state.status) {
      case AttendanceStatus.detecting:
        msg = '🔍 Detecting face...';
        color = AppColors.warning;
        break;
      case AttendanceStatus.processing:
        msg = '⚙️ Processing...';
        color = AppColors.info;
        break;
      case AttendanceStatus.verifying:
        msg = '🔐 Verifying identity...';
        color = AppColors.primary;
        break;
      case AttendanceStatus.locating:
        msg = '📍 Getting your location...';
        color = Colors.tealAccent;
        break;
      case AttendanceStatus.afterOfficeHours:
        msg = '🕕 Check-in blocked after 6 PM';
        color = Colors.red;
        break;
      case AttendanceStatus.autoCheckoutSuccess:
        msg = '✅ Auto checked out at 6 PM';
        color = Colors.green;
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: color,
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate(key: ValueKey(state.status)).fadeIn(duration: 300.ms);
  }

  Widget _buildControls(AttendanceState state) {
    final isBusy =
        state.status == AttendanceStatus.detecting ||
        state.status == AttendanceStatus.processing ||
        state.status == AttendanceStatus.verifying ||
        state.status == AttendanceStatus.locating;

    final canMark = state.status == AttendanceStatus.cameraReady;
    final isCheckInAction = !state.hasCheckedIn || state.hasCheckedOut;

    final buttonLabel = isBusy
        ? 'Processing...'
        : isCheckInAction
        ? 'Check In'
        : 'Check Out';

    final buttonIcon = isCheckInAction
        ? Icons.login_rounded
        : Icons.logout_rounded;
    final buttonColor = isCheckInAction ? Colors.green : Colors.red;

    final hintText = state.hasCheckedIn && !state.hasCheckedOut
        ? 'Align your face and tap to Check Out'
        : state.hasCheckedIn && state.hasCheckedOut
        ? 'Back in office? Align face to Check In again'
        : 'Align your face and tap to Check In';

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hintText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: buttonLabel,
            isLoading: isBusy,
            icon: buttonIcon,
            backgroundColor: buttonColor,
            onPressed: canMark ? () => _notifier.markAttendance() : null,
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  bool _isResultState(AttendanceStatus status) =>
      status == AttendanceStatus.checkInSuccess ||
      status == AttendanceStatus.checkOutSuccess ||
      status == AttendanceStatus.autoCheckoutSuccess ||
      status == AttendanceStatus.faceMismatch ||
      status == AttendanceStatus.faceNotRegistered ||
      status == AttendanceStatus.alreadyCheckedOut ||
      status == AttendanceStatus.afterOfficeHours ||
      status == AttendanceStatus.error;
}

// ── _CompactStatusStrip ───────────────────────────────────────
class _CompactStatusStrip extends StatelessWidget {
  final AttendanceState state;
  const _CompactStatusStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final isWFO = state.todayStatus?.toLowerCase() == 'present';
    final workModeEmoji = isWFO ? '🏢' : '🏠';
    final workModeText = isWFO ? 'Work From Office' : 'Work From Home';
    final workModeColor = isWFO ? Colors.green : Colors.blue;

    final isDataLoaded =
        state.status != AttendanceStatus.idle &&
        state.status != AttendanceStatus.initializing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hPad = w < 360 ? 10.0 : 14.0;
        final vPad = w < 360 ? 10.0 : 12.0;

        return Container(
          color: const Color(0xFF1A1A1A),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            children: [
              Flexible(
                flex: 2,
                child: _StripItem(
                  icon: Icons.login,
                  iconColor: Colors.green,
                  label: 'First In',
                  value: state.checkInTime ?? '--:--',
                  screenWidth: w,
                ),
              ),
              _divider(),
              Flexible(
                flex: 2,
                child: _StripItem(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  label: 'Last Out',
                  value: state.checkOutTime ?? '--:--',
                  screenWidth: w,
                ),
              ),
              _divider(),
              Flexible(
                flex: 2,
                child: _StripItem(
                  icon: Icons.access_time_rounded,
                  iconColor: Colors.amber,
                  label: 'Total',
                  value: state.todayRecord?.totalHours != null
                      ? '${state.todayRecord!.totalHours!.toStringAsFixed(1)}h'
                      : '--',
                  screenWidth: w,
                ),
              ),
              _divider(),
              Flexible(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isDataLoaded && state.hasCheckedIn)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: workModeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: workModeColor.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  workModeEmoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  workModeText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: workModeColor,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isDataLoaded && state.isLate) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('⚠️', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 5),
                                Text(
                                  'Late Check-In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white12,
  );
}

class _StripItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double screenWidth;

  const _StripItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final labelSize = screenWidth < 360 ? 9.0 : 10.0;
    final valueSize = screenWidth < 360 ? 11.0 : 12.0;
    final iconSize = screenWidth < 360 ? 12.0 : 14.0;
    final isDimmed = value == '--:--' || value == '--';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.white38,
                  fontFamily: 'Poppins',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w600,
                  color: isDimmed ? Colors.white30 : Colors.white,
                  fontFamily: 'Poppins',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
