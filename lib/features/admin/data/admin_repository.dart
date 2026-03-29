import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class AdminRepository {
  final _client = Supabase.instance.client;

  // ── getEmployeesWithTodayStatus() ───────────────────────────
  Future<List<Map<String, dynamic>>> getEmployeesWithTodayStatus() async {
    return fetchEmployeesWithAttendance(DateTime.now());
  }

  // ── fetchEmployeesWithAttendance() ──────────────────────────
  Future<List<Map<String, dynamic>>> fetchEmployeesWithAttendance(
    DateTime date,
  ) async {
    final dateStr = _dateString(date);
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email, department, avatar_url, role')
          .eq('role', 'employee')
          .order('full_name', ascending: true);

      AppLogger.debug('Profiles fetched: ${profiles.length}');

      final attendance = await _client
          .from('attendance')
          .select(
            'id, user_id, status, check_in_time, check_out_time, '
            'is_late, total_hours',
          )
          .eq('date', dateStr);

      AppLogger.debug('Attendance for $dateStr: ${attendance.length}');

      final attendanceMap = <String, Map<String, dynamic>>{};
      for (final record in attendance) {
        attendanceMap[record['user_id'] as String] = record;
      }

      final result = profiles.map<Map<String, dynamic>>((profile) {
        final userId = profile['id'] as String;
        final att = attendanceMap[userId];
        return {
          ...profile,
          'attendance_id': att?['id'],
          'status': att?['status'],
          'check_in_time': att?['check_in_time'],
          'check_out_time': att?['check_out_time'],
          'is_late': att?['is_late'],
          'total_hours': att?['total_hours'],
        };
      }).toList();

      AppLogger.info('✅ ${result.length} employees loaded for $dateStr');
      return result;
    } on PostgrestException catch (e) {
      AppLogger.error('fetchEmployeesWithAttendance failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('fetchEmployeesWithAttendance error', e, st);
      rethrow;
    }
  }

  // ── getMonthlyReport() ──────────────────────────────────────
  // PURPOSE: Per-employee attendance summary for a full month
  // WHY two queries not join: Supabase free tier join is limited
  //   Query 1 → all employees (profiles)
  //   Query 2 → all attendance records for the month
  //   Then join in Dart → fast + no extra DB cost
  //
  // Returns per employee:
  //   present_days, wfh_days, absent_days, late_days, total_hours
  Future<List<Map<String, dynamic>>> getMonthlyReport(DateTime month) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstStr = _dateString(firstDay);
    final lastStr = _dateString(lastDay);

    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email, department')
          .eq('role', 'employee')
          .order('full_name', ascending: true);

      AppLogger.debug('Report profiles: ${profiles.length}');

      final attendance = await _client
          .from('attendance')
          .select(
            'user_id, date, status, is_late, '
            'total_hours, check_in_time, check_out_time',
          )
          .gte('date', firstStr)
          .lte('date', lastStr);

      AppLogger.debug(
        'Report attendance: ${attendance.length} | $firstStr → $lastStr',
      );

      // Group attendance records by user_id
      final attByUser = <String, List<Map<String, dynamic>>>{};
      for (final r in attendance) {
        final uid = r['user_id'] as String;
        attByUser.putIfAbsent(uid, () => []).add(r);
      }

      final result = profiles.map<Map<String, dynamic>>((profile) {
        final uid = profile['id'] as String;
        final records = attByUser[uid] ?? [];

        final presentDays = records
            .where((r) => r['status'] == 'present')
            .length;
        final wfhDays = records.where((r) => r['status'] == 'wfh').length;
        final absentDays = records.where((r) => r['status'] == 'absent').length;
        final lateDays = records.where((r) => r['is_late'] == true).length;
        final totalHours = records.fold<double>(
          0.0,
          (sum, r) => sum + ((r['total_hours'] as num?)?.toDouble() ?? 0.0),
        );

        return {
          ...profile,
          'present_days': presentDays,
          'wfh_days': wfhDays,
          'absent_days': absentDays,
          'late_days': lateDays,
          'total_hours': double.parse(totalHours.toStringAsFixed(1)),
          'records': records, // ← full daily records for drill-down
        };
      }).toList();

      AppLogger.info('✅ Monthly report: ${result.length} employees');
      return result;
    } on PostgrestException catch (e) {
      AppLogger.error('getMonthlyReport failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getMonthlyReport error', e, st);
      rethrow;
    }
  }

  // ── updateAttendance() ──────────────────────────────────────
  Future<void> updateAttendance({
    required String attendanceId,
    required String status,
    String? checkOutTime,
  }) async {
    try {
      await _client
          .from('attendance')
          .update({
            'status': status,
            'check_out_time': checkOutTime,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', attendanceId);

      AppLogger.info('✅ Attendance updated: $attendanceId → $status');
    } on PostgrestException catch (e) {
      AppLogger.error('updateAttendance failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('updateAttendance error', e, st);
      rethrow;
    }
  }

  // ── getAttendanceByDate() ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    try {
      final response = await _client
          .from('attendance')
          .select(
            'id, user_id, date, status, check_in_time, check_out_time, '
            'total_hours, is_late, location_lat, location_lng, '
            'profiles(full_name, email, department)',
          )
          .eq('date', date)
          .order('check_in_time', ascending: true);

      AppLogger.debug('Records for $date: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error('getAttendanceByDate failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getAttendanceByDate error', e, st);
      rethrow;
    }
  }

  // ── getTodaySummary() ───────────────────────────────────────
  Future<Map<String, int>> getTodaySummary() async {
    final today = _dateString(DateTime.now());
    try {
      final response = await _client
          .from('attendance')
          .select('status')
          .eq('date', today);

      int present = 0, wfh = 0, absent = 0;
      for (final r in response) {
        switch (r['status']) {
          case 'present':
            present++;
            break;
          case 'wfh':
            wfh++;
            break;
          case 'absent':
            absent++;
            break;
        }
      }

      AppLogger.debug('Summary → P:$present W:$wfh A:$absent');
      return {'present': present, 'wfh': wfh, 'absent': absent};
    } on PostgrestException catch (e) {
      AppLogger.error('getTodaySummary failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getTodaySummary error', e, st);
      rethrow;
    }
  }

  // ── getAllEmployees() ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, department, avatar_url, role')
          .eq('role', 'employee')
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error('getAllEmployees failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getAllEmployees error', e, st);
      rethrow;
    }
  }

  // ── _dateString() ──────────────────────────────────────────
  String _dateString(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

// ✅ Global singleton
final adminRepository = AdminRepository();
