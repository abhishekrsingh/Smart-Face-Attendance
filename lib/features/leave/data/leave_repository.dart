import 'package:face_track/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveRepository {
  final _client = Supabase.instance.client;

  // ── applyLeave() ──────────────────────────────────────────────
  Future<void> applyLeave({
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final overlap = await _client
          .from('leave_requests')
          .select('id, start_date, end_date, status')
          .eq('user_id', userId)
          .lte('start_date', _dateStr(endDate))
          .gte('end_date', _dateStr(startDate))
          .inFilter('status', ['pending', 'approved'])
          .maybeSingle();

      if (overlap != null) {
        final from = overlap['start_date'] as String;
        final to = overlap['end_date'] as String;
        final status = overlap['status'] as String;
        throw Exception(
          'You already have a $status leave request '
          'for $from → $to.\n'
          'Please choose non-overlapping dates.',
        );
      }

      await _client.from('leave_requests').insert({
        'user_id': userId,
        'start_date': _dateStr(startDate),
        'end_date': _dateStr(endDate),
        'leave_type': leaveType,
        'reason': reason,
        'status': 'pending',
      });

      AppLogger.info(
        '✅ Leave applied: $leaveType | '
        '${_dateStr(startDate)} → ${_dateStr(endDate)}',
      );
    } on PostgrestException catch (e) {
      AppLogger.error('applyLeave failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('applyLeave error', e, st);
      rethrow;
    }
  }

  // ── getMyLeaves() ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyLeaves() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final data = await _client
          .from('leave_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      AppLogger.debug('My leaves: ${data.length}');
      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      AppLogger.error('getMyLeaves failed: ${e.message}');
      rethrow;
    }
  }

  // ── checkApprovedLeaveForDate() ───────────────────────────────
  // PURPOSE: Used by home_page before allowing Mark Absent
  Future<bool> checkApprovedLeaveForDate(DateTime date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final result = await _client
          .from('leave_requests')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'approved')
          .lte('start_date', _dateStr(date))
          .gte('end_date', _dateStr(date))
          .maybeSingle();

      final hasApproval = result != null;
      AppLogger.debug('checkApprovedLeave(${_dateStr(date)}) → $hasApproval');
      return hasApproval;
    } on PostgrestException catch (e) {
      AppLogger.error('checkApprovedLeave failed: ${e.message}');
      rethrow;
    }
  }

  // ── updateLeave() ─────────────────────────────────────────────
  // PURPOSE: Employee edits a PENDING leave request
  // GUARD: Re-checks status before update
  Future<void> updateLeave({
    required String leaveId,
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final existing = await _client
          .from('leave_requests')
          .select('status')
          .eq('id', leaveId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) throw Exception('Leave request not found.');
      if (existing['status'] != 'pending') {
        throw Exception(
          'Cannot edit — leave is already ${existing['status']}.',
        );
      }

      final overlap = await _client
          .from('leave_requests')
          .select('id, start_date, end_date, status')
          .eq('user_id', userId)
          .neq('id', leaveId)
          .lte('start_date', _dateStr(endDate))
          .gte('end_date', _dateStr(startDate))
          .inFilter('status', ['pending', 'approved'])
          .maybeSingle();

      if (overlap != null) {
        final from = overlap['start_date'] as String;
        final to = overlap['end_date'] as String;
        final status = overlap['status'] as String;
        throw Exception(
          'Dates overlap with a $status leave ($from → $to).\n'
          'Please choose non-overlapping dates.',
        );
      }

      await _client
          .from('leave_requests')
          .update({
            'start_date': _dateStr(startDate),
            'end_date': _dateStr(endDate),
            'leave_type': leaveType,
            'reason': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', leaveId)
          .eq('user_id', userId);

      AppLogger.info(
        '✅ Leave updated: $leaveId | $leaveType | '
        '${_dateStr(startDate)} → ${_dateStr(endDate)}',
      );
    } on PostgrestException catch (e) {
      AppLogger.error('updateLeave failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('updateLeave error', e, st);
      rethrow;
    }
  }

  // ── cancelLeave() ─────────────────────────────────────────────
  // PURPOSE: Employee cancels their own PENDING leave
  // WHY update not delete: keeps history in admin panel
  Future<void> cancelLeave({required String leaveId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final existing = await _client
          .from('leave_requests')
          .select('status')
          .eq('id', leaveId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) throw Exception('Leave request not found.');
      if (existing['status'] != 'pending') {
        throw Exception(
          'Cannot cancel — leave is already ${existing['status']}.',
        );
      }

      await _client
          .from('leave_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', leaveId)
          .eq('user_id', userId);

      AppLogger.info('✅ Leave cancelled: $leaveId');
    } on PostgrestException catch (e) {
      AppLogger.error('cancelLeave failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('cancelLeave error', e, st);
      rethrow;
    }
  }

  // ── deleteLeave() ─────────────────────────────────────────────
  // PURPOSE: Hard delete an approved/rejected/cancelled leave
  // WHY allow approved: admin already actioned it —
  //   employee just clearing their own leave history
  // WHY block pending: use cancelLeave() for pending —
  //   so admin can see it was withdrawn, not silently deleted
  Future<void> deleteLeave({required String leaveId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      // ── Safety re-check ──────────────────────────────────────
      final existing = await _client
          .from('leave_requests')
          .select('status')
          .eq('id', leaveId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) throw Exception('Leave request not found.');

      final status = existing['status'] as String;

      if (status == 'pending') {
        throw Exception(
          'Cannot delete a pending leave.\n'
          'Please use the Cancel option instead.',
        );
      }

      await _client
          .from('leave_requests')
          .delete()
          .eq('id', leaveId)
          .eq('user_id', userId);

      AppLogger.info('✅ Leave deleted: $leaveId ($status)');
    } on PostgrestException catch (e) {
      AppLogger.error('deleteLeave failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('deleteLeave error', e, st);
      rethrow;
    }
  }

  // ── _dateStr() ────────────────────────────────────────────────
  String _dateStr(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

final leaveRepository = LeaveRepository();
