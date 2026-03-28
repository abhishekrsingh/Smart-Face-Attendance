import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

class AttendanceRepository {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final userId = _client.auth.currentUser!.id;
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
      final data = {
        'user_id': userId,
        'date': today,
        'check_in_time': nowUtc.toIso8601String(),
        'status': status,
        'is_late': isLate,
        'location_lat': lat,
        'location_lng': lng,
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      };

      final response = await _client
          .from('attendance')
          .insert(data)
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

  Future<Map<String, dynamic>> checkOut({
    required String attendanceId,
    required double? lat,
    required double? lng,
  }) async {
    final nowUtc = DateTime.now().toUtc();

    try {
      final existing = await _client
          .from('attendance')
          .select('check_in_time')
          .eq('id', attendanceId)
          .single();

      final checkInUtc = DateTime.parse(existing['check_in_time'] as String);
      final totalHours = nowUtc.difference(checkInUtc).inMinutes / 60.0;

      final response = await _client
          .from('attendance')
          .update({
            'check_out_time': nowUtc.toIso8601String(),
            'total_hours': double.parse(totalHours.toStringAsFixed(2)),
            'location_lat': lat,
            'location_lng': lng,
            'updated_at': nowUtc.toIso8601String(),
          })
          .eq('id', attendanceId)
          .select()
          .single();

      AppLogger.info(
        '✅ Check-out done. Total hours: ${totalHours.toStringAsFixed(2)}',
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
          .single();

      AppLogger.info('✅ Re check-in done: $attendanceId');
      return response;
    } on PostgrestException catch (e) {
      AppLogger.error('Re check-in failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Re check-in error', e, st);
      rethrow;
    }
  }

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
        AppLogger.info('Attendance already marked for today — skipping absent');
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

      AppLogger.info('✅ Marked absent for: $today');
    } on PostgrestException catch (e) {
      AppLogger.error('Mark absent failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Mark absent error', e, st);
      rethrow;
    }
  }

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

  String _localDateString() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

// ✅ ONLY attendanceRepository here — nothing else
final attendanceRepository = AttendanceRepository();
