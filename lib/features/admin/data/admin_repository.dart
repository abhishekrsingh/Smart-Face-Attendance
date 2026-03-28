import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class AdminRepository {
  final _client = Supabase.instance.client;

  // ── getEmployeesWithTodayStatus() ───────────────────────────
  Future<List<Map<String, dynamic>>> getEmployeesWithTodayStatus() async {
    return fetchEmployeesWithAttendance(DateTime.now());
  }

  // ── fetchEmployeesWithAttendance() ──────────────────────────
  // PURPOSE: Fetch all employees + their attendance for ANY date
  //
  // REAL SCENARIOS where admin uses this:
  //   Scenario 1 — Wrong Status:
  //     Employee GPS marked WFH but was actually in office
  //     Admin picks today → finds employee → taps ✏️ → fixes status
  //
  //   Scenario 2 — Forgot Checkout:
  //     Employee left at 6 PM but forgot to tap Check Out
  //     Admin picks today → finds employee → clears checkout
  //     Employee can now check out from their own phone
  //
  //   Scenario 3 — Past Date Audit:
  //     HR auditing last Monday → admin picks that date
  //     Sees all 15 employees' status → edits errors
  //
  // WHY attendance_id separate from profile id:
  //   profiles.id   = user UUID  (who the person is)
  //   attendance.id = record UUID (what to UPDATE in DB)
  //   Without attendance_id, updateAttendance() would
  //   use user UUID → 0 rows matched → silent fail ❌
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
            // WHY id included: needed as attendance_id for updateAttendance()
            // Without this, edit sheet uses user UUID → wrong row updated
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
          // WHY attendance_id not 'id':
          //   ...profile already sets 'id' = user UUID
          //   storing attendance record id separately prevents collision
          //   _showEditDialog() reads 'attendance_id' for DB update
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

  // ── updateAttendance() ──────────────────────────────────────
  // PURPOSE: Admin manually corrects an attendance record
  //
  // Scenario 1 — Status fix:
  //   updateAttendance(attendanceId: 'xyz', status: 'present', ...)
  //   → changes WFH → Present in DB
  //
  // Scenario 2 — Clear checkout:
  //   updateAttendance(attendanceId: 'xyz', checkOutTime: null, ...)
  //   → removes check_out_time → employee can check out again
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
