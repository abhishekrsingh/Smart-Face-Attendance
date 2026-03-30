import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:face_track/core/utils/app_logger.dart';
import 'package:face_track/data/remote/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final _client = SupabaseService.client;

  // ── getProfile() ──────────────────────────────────────────────
  // PURPOSE: Fetch current employee's full profile from DB
  Future<Map<String, dynamic>> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, email, department, avatar_url, role')
          .eq('id', userId)
          .single();

      AppLogger.debug('Profile fetched: ${data['full_name']}');
      return Map<String, dynamic>.from(data);
    } on PostgrestException catch (e) {
      AppLogger.error('getProfile failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getProfile error', e, st);
      rethrow;
    }
  }

  // ── updateProfile() ───────────────────────────────────────────
  // PURPOSE: Update employee name and department
  // WHY not email: email change requires auth-level flow
  Future<void> updateProfile({
    required String fullName,
    required String department,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    if (fullName.trim().isEmpty) {
      throw Exception('Name cannot be empty.');
    }

    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName.trim(),
            'department': department.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('✅ Profile updated: $fullName | $department');
    } on PostgrestException catch (e) {
      AppLogger.error('updateProfile failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('updateProfile error', e, st);
      rethrow;
    }
  }

  // ── uploadAvatar() ────────────────────────────────────────────
  // PURPOSE: Upload avatar image to Supabase storage + save URL
  // WHY http not SDK: supabase_flutter uploadBinary() has a
  //   known 404 bug — raw HTTP is reliable and predictable
  Future<String> uploadAvatar({required File imageFile}) async {
    final userId = _client.auth.currentUser?.id;
    final session = _client.auth.currentSession;
    if (userId == null || session == null) {
      throw Exception('Not logged in');
    }

    try {
      // ── Detect MIME type from extension ──────────────────
      // WHY dynamic: PNG fails if sent as image/jpeg
      final ext = imageFile.path.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      // ── Unique path per upload ────────────────────────────
      // WHY timestamp suffix: busts CDN cache on re-upload
      // WHY userId folder: matches RLS split_part policy
      final filePath =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final uploadUrl =
          '${SupabaseService.supabaseUrl}'
          '/storage/v1/object/avatars/$filePath';

      AppLogger.debug('Uploading avatar → $filePath | type: $contentType');

      final bytes = await imageFile.readAsBytes();
      final headers = {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': contentType,
        'x-upsert': 'true',
      };

      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      );

      AppLogger.debug(
        'Upload response: ${response.statusCode} | ${response.body}',
      );

      if (response.statusCode != 200) {
        throw StorageException(
          'Upload failed: ${response.body}',
          statusCode: '${response.statusCode}',
        );
      }

      // ── Build public URL ──────────────────────────────────
      final publicUrl =
          '${SupabaseService.supabaseUrl}'
          '/storage/v1/object/public/avatars/$filePath';

      // ── Save URL back to profiles table ──────────────────
      await _client
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('✅ Avatar uploaded: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      AppLogger.error('uploadAvatar failed: ${e.message} | ${e.statusCode}');
      rethrow;
    } on PostgrestException catch (e) {
      AppLogger.error('uploadAvatar db failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('uploadAvatar error', e, st);
      rethrow;
    }
  }

  // ── changePassword() ──────────────────────────────────────────
  // PURPOSE: Change authenticated user's password
  // WHY re-sign-in first: verifies current password manually
  //   since Supabase updateUser() skips current password check
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw Exception('Not logged in');

    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters.');
    }
    if (currentPassword == newPassword) {
      throw Exception('New password must be different from current password.');
    }

    try {
      // ── Step 1: Verify current password ──────────────────
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // ── Step 2: Update to new password ───────────────────
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      AppLogger.info('✅ Password changed for $email');
    } on AuthException catch (e) {
      AppLogger.error('changePassword failed: ${e.message}');
      if (e.message.toLowerCase().contains('invalid')) {
        throw Exception('Current password is incorrect.');
      }
      rethrow;
    } catch (e, st) {
      AppLogger.error('changePassword error', e, st);
      rethrow;
    }
  }

  // ── getAttendanceSummary() ────────────────────────────────────
  // PURPOSE: Monthly attendance stats for profile summary cards
  // WHY current month only: relevant recent data without
  //   overwhelming with full history
  Future<Map<String, dynamic>> getAttendanceSummary() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    try {
      final records = await _client
          .from('attendance')
          .select('status, is_late, total_hours, date')
          .eq('user_id', userId)
          .gte('date', _dateStr(firstDay))
          .lte('date', _dateStr(lastDay));

      final presentDays = records.where((r) => r['status'] == 'present').length;
      final wfhDays = records.where((r) => r['status'] == 'wfh').length;
      final absentDays = records.where((r) => r['status'] == 'absent').length;
      final lateDays = records.where((r) => r['is_late'] == true).length;
      final totalHours = records.fold<double>(
        0.0,
        (sum, r) => sum + ((r['total_hours'] as num?)?.toDouble() ?? 0.0),
      );

      AppLogger.debug(
        'Attendance summary → '
        'P:$presentDays W:$wfhDays '
        'A:$absentDays L:$lateDays H:$totalHours',
      );

      return {
        'present_days': presentDays,
        'wfh_days': wfhDays,
        'absent_days': absentDays,
        'late_days': lateDays,
        'total_hours': double.parse(totalHours.toStringAsFixed(1)),
        'total_days': presentDays + wfhDays + absentDays,
        'month_label': _monthLabel(now),
      };
    } on PostgrestException catch (e) {
      AppLogger.error('getAttendanceSummary failed: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('getAttendanceSummary error', e, st);
      rethrow;
    }
  }

  // ── _dateStr() ────────────────────────────────────────────────
  String _dateStr(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  // ── _monthLabel() ─────────────────────────────────────────────
  String _monthLabel(DateTime dt) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month]} ${dt.year}';
  }
}

final profileRepository = ProfileRepository();
