import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/attendance_provider.dart';

// WHY: Separate overlay widget — displayed on top of camera
// to show real-time recognition result without blocking preview
class RecognitionOverlay extends StatelessWidget {
  final AttendanceStatus status;
  final String? message;
  final double? confidence;

  const RecognitionOverlay({
    super.key,
    required this.status,
    this.message,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    // WHY: Only show overlay on result states — not during idle/cameraReady
    final showOverlay =
        status == AttendanceStatus.checkInSuccess ||
        status == AttendanceStatus.checkOutSuccess ||
        status == AttendanceStatus.faceMismatch ||
        status == AttendanceStatus.faceNotRegistered ||
        status == AttendanceStatus.alreadyCheckedOut ||
        status == AttendanceStatus.error;

    if (!showOverlay) return const SizedBox.shrink();

    final isSuccess =
        status == AttendanceStatus.checkInSuccess ||
        status == AttendanceStatus.checkOutSuccess ||
        status == AttendanceStatus.alreadyCheckedOut;

    final color = isSuccess ? AppColors.present : AppColors.error;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 72).animate().scale(
              begin: const Offset(0.3, 0.3),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),

            const SizedBox(height: 20),

            Text(
              message ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 200.ms),

            // WHY: Show confidence score for debugging + user trust
            if (confidence != null) ...[
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(confidence! * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],

            const SizedBox(height: 32),

            // WHY: Auto-dismiss hint so user knows it will reset
            const Text(
              'Tap anywhere to scan again',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
