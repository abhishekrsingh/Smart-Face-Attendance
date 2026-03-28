import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

// WHY: Separate widget keeps mark_attendance_page clean.
// Shows today's check-in/out status at top of screen.
class AttendanceStatusCard extends StatelessWidget {
  final Map<String, dynamic>? todayRecord;

  const AttendanceStatusCard({super.key, required this.todayRecord});

  @override
  Widget build(BuildContext context) {
    if (todayRecord == null) {
      return _buildCard(
        icon: Icons.radio_button_unchecked_rounded,
        title: 'Not Checked In',
        subtitle: 'Scan your face to check in',
        color: Colors.white38,
      );
    }

    final checkIn = todayRecord!['check_in_time'];
    final checkOut = todayRecord!['check_out_time'];
    final isLate = todayRecord!['is_late'] == true;
    final totalHours = todayRecord!['total_hours'];

    if (checkOut != null) {
      return _buildCard(
        icon: Icons.check_circle_rounded,
        title: 'Attendance Complete',
        subtitle: 'Total: ${totalHours ?? '--'} hrs',
        color: AppColors.present,
        extra: '${_fmt(checkIn)} → ${_fmt(checkOut)}',
      );
    }

    return _buildCard(
      icon: isLate ? Icons.warning_amber_rounded : Icons.login_rounded,
      title: isLate ? 'Checked In (Late)' : 'Checked In',
      subtitle: 'Check-in: ${_fmt(checkIn)}',
      color: isLate ? AppColors.warning : AppColors.primary,
      extra: 'Scan again to check out',
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? extra,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'Poppins',
                    fontSize: 12,
                  ),
                ),
                if (extra != null)
                  Text(
                    extra,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Poppins',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  String _fmt(String? iso) {
    if (iso == null) return '--:--';
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
