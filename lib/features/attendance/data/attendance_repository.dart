import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class AttendanceRepository {
  final _client = Supabase.instance.client;

  // ── getTodayAttendance() ────────────────────────────────────
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final today = _localDateString();

    try {
      final response = await _client
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      AppLogger.debug('Today attendance: $response');
      return response;
    } catch (e) {
      AppLogger.error('Get attendance failed', e);
      return null;
    }
  }

  // ── getMonthlyAttendance() ──────────────────────────────────
  // PURPOSE: Employee's own attendance for a full month
  // WHY month param: history screen navigates between months
  // WHY userId from currentUser: employee sees only their own
  Future<List<Map<String, dynamic>>> getMonthlyAttendance(
    DateTime month,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // First and last day of the given month
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final firstStr = _localDateString(firstDay);
    final lastStr = _localDateString(lastDay);

    try {
      final response = await _client
          .from('attendance')
          .select(
            'id, date, status, check_in_time, check_out_time, '
            'is_late, total_hours',
          )
          .eq('user_id', userId)
          .gte('date', firstStr)
          .lte('date', lastStr)
          .order('date', ascending: false);

      AppLogger.debug(
        'Monthly: ${response.length} records | $firstStr → $lastStr',
      );
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.error('getMonthlyAttendance failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getMonthlyAttendance error', e, st);
      rethrow;
    }
  }

  // ── checkForMissedCheckout() ────────────────────────────────
  // Rule 1: Past day checked in, no checkout → auto-checkout +8h
  // Rule 2: Same day, 8h elapsed, no checkout → auto-checkout +8h
  Future<int> checkForMissedCheckout() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final today = _localDateString();
    int autoCount = 0;

    try {
      // ── Rule 1: Past days ───────────────────────────────────
      final pastRecords = await _client
          .from('attendance')
          .select('id, check_in_time, date, status')
          .eq('user_id', userId)
          .lt('date', today)
          .filter('check_out_time', 'is', null)
          .neq('status', 'absent');

      for (final record in pastRecords) {
        final checkInUtc = DateTime.parse(record['check_in_time'] as String);
        final autoCheckOutUtc = checkInUtc.add(const Duration(hours: 8));

        await _client
            .from('attendance')
            .update({
              'check_out_time': autoCheckOutUtc.toIso8601String(),
              'total_hours': 8.0,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', record['id'] as String);

        autoCount++;
        AppLogger.info(
          '✅ Auto-checkout (past): ${record['id']} | ${record['date']}',
        );
      }

      // ── Rule 2: Today, 8h elapsed ───────────────────────────
      final todayRecord = await _client
          .from('attendance')
          .select('id, check_in_time')
          .eq('user_id', userId)
          .eq('date', today)
          .filter('check_out_time', 'is', null)
          .neq('status', 'absent')
          .maybeSingle();

      if (todayRecord != null) {
        final checkInUtc = DateTime.parse(
          todayRecord['check_in_time'] as String,
        );
        final nowUtc = DateTime.now().toUtc();
        final hoursSince = nowUtc.difference(checkInUtc).inMinutes / 60.0;

        if (hoursSince >= 8) {
          final autoCheckOutUtc = checkInUtc.add(const Duration(hours: 8));

          await _client
              .from('attendance')
              .update({
                'check_out_time': autoCheckOutUtc.toIso8601String(),
                'total_hours': 8.0,
                'updated_at': nowUtc.toIso8601String(),
              })
              .eq('id', todayRecord['id'] as String);

          autoCount++;
          AppLogger.info('✅ Auto-checkout (8h elapsed): ${todayRecord['id']}');
        }
      }

      if (autoCount > 0) {
        AppLogger.info('✅ Auto-checked out $autoCount record(s)');
      }
      return autoCount;
    } catch (e, st) {
      AppLogger.error('checkForMissedCheckout error', e, st);
      return 0;
    }
  }

  // ── checkIn() ──────────────────────────────────────────────
  Future<Map<String, dynamic>> checkIn({
    required double confidence,
    required double? lat,
    required double? lng,
    required String status,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final nowLocal = DateTime.now();
    final nowUtc = nowLocal.toUtc();
    final today = _localDateString();
    final isLate = nowLocal.hour >= 9;

    try {
      final response = await _client
          .from('attendance')
          .insert({
            'user_id': userId,
            'date': today,
            'check_in_time': nowUtc.toIso8601String(),
            'status': status,
            'is_late': isLate,
            'location_lat': lat,
            'location_lng': lng,
            'created_at': nowUtc.toIso8601String(),
            'updated_at': nowUtc.toIso8601String(),
          })
          .select()
          .single();

      AppLogger.info(
        '✅ Check-in: ${response['id']} | status: $status | late: $isLate',
      );
      return response;
    } on PostgrestException catch (e) {
      AppLogger.error('Check-in failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Check-in error', e, st);
      rethrow;
    }
  }

  // ── checkOut() ─────────────────────────────────────────────
  // FIX: Accept checkInTime as param — no extra DB fetch
  // WHY: caller has check_in_time in state already
  // Cap checkout at 6 PM — hours after office time don't count
  Future<Map<String, dynamic>> checkOut({
    required String attendanceId,
    required String checkInTime,
    required double? lat,
    required double? lng,
  }) async {
    final nowLocal = DateTime.now();

    // ── Cap at 6 PM ─────────────────────────────────────────
    // WHY: office ends at 6 PM — no hours counted after that
    final sixPmLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      18,
      0,
    );
    final effectiveLocal = nowLocal.isAfter(sixPmLocal) ? sixPmLocal : nowLocal;
    final effectiveUtc = effectiveLocal.toUtc();

    try {
      final checkInUtc = DateTime.parse(checkInTime);
      final rawHours = effectiveUtc.difference(checkInUtc).inMinutes / 60.0;
      final totalHours = rawHours.clamp(0.0, 8.0);

      final response = await _client
          .from('attendance')
          .update({
            'check_out_time': effectiveUtc.toIso8601String(),
            'total_hours': double.parse(totalHours.toStringAsFixed(2)),
            'location_lat': lat,
            'location_lng': lng,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', attendanceId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Record not found — ID: $attendanceId');
      }

      AppLogger.info(
        '✅ Check-out: ${effectiveLocal.hour}:${effectiveLocal.minute.toString().padLeft(2, '0')} | ${totalHours.toStringAsFixed(2)}h',
      );
      return response;
    } on PostgrestException catch (e) {
      AppLogger.error('Check-out failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Check-out error', e, st);
      rethrow;
    }
  }

  // ── reCheckIn() ────────────────────────────────────────────
  Future<Map<String, dynamic>> reCheckIn({required String attendanceId}) async {
    try {
      final response = await _client
          .from('attendance')
          .update({
            'check_out_time': null,
            'total_hours': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', attendanceId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Record not found — ID: $attendanceId');
      }

      AppLogger.info('✅ Re check-in: $attendanceId');
      return response;
    } on PostgrestException catch (e) {
      AppLogger.error('Re check-in failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Re check-in error', e, st);
      rethrow;
    }
  }

  // ── markAbsent() ───────────────────────────────────────────
  Future<void> markAbsent() async {
    final userId = _client.auth.currentUser!.id;
    final today = _localDateString();
    final nowUtc = DateTime.now().toUtc();

    try {
      final existing = await _client
          .from('attendance')
          .select('id')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (existing != null) {
        throw Exception('You have already marked attendance for today.');
      }

      await _client.from('attendance').insert({
        'user_id': userId,
        'date': today,
        'status': 'absent',
        'is_late': false,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      AppLogger.info('✅ Marked absent: $today');
    } on PostgrestException catch (e) {
      AppLogger.error('Mark absent failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Mark absent error', e, st);
      rethrow;
    }
  }

  // ── getAttendanceHistory() ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    final userId = _client.auth.currentUser!.id;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);

    try {
      final response = await _client
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .gte('date', sevenDaysAgo)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('History fetch failed', e);
      return [];
    }
  }

  // ── _localDateString() ─────────────────────────────────────
  // WHY optional param: works for today (no param)
  // AND any specific date (pass DateTime) — used by monthly fetch
  String _localDateString([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

// ✅ Global singleton
final attendanceRepository = AttendanceRepository();
