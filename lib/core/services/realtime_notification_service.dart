import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/remote/supabase_service.dart';

// ── RealtimeNotificationService ───────────────────────────────
// PURPOSE: Central service for all push-style local notifications
//   triggered by Supabase Realtime Postgres changes
class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final instance = RealtimeNotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _client = SupabaseService.client;

  static const _channel = AndroidNotificationChannel(
    'face_attend_channel',
    'FaceAttend Notifications',
    description: 'Attendance & leave alerts',
    importance: Importance.high,
  );

  // ── initialize() ─────────────────────────────────────────
  Future<void> initialize() async {
    // ── Create Android channel ──────────────────────────
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // ── Request Android 13+ permission ─────────────────
    final granted = await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    AppLogger.debug('Notification permission granted: $granted');

    // ── Initialize plugin ───────────────────────────────
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        AppLogger.debug('Notification tapped: ${response.payload}');
      },
    );

    AppLogger.info('✅ RealtimeNotificationService initialized');
  }

  // ── listenLeaveUpdates() ──────────────────────────────
  // PURPOSE: Employee gets notified when admin
  //   approves or rejects their leave request
  // WHY filter by user_id: only show notifications
  //   relevant to the logged-in employee
  void listenLeaveUpdates() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.error('listenLeaveUpdates: userId is null');
      return;
    }

    _client
        .channel('leave_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'leave_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            final oldStatus = payload.oldRecord['status'] as String?;

            AppLogger.debug('Leave status: $oldStatus → $newStatus');

            // WHY check oldStatus != newStatus: Supabase
            //   sometimes fires update on unrelated column
            //   changes — only notify on actual status change
            if (oldStatus == newStatus) return;

            switch (newStatus) {
              case 'approved':
                _show(
                  id: 2001,
                  title: '✅ Leave Approved',
                  body:
                      'Your leave request has been '
                      'approved by admin.',
                );
              case 'rejected':
                _show(
                  id: 2002,
                  title: '❌ Leave Rejected',
                  body:
                      'Your leave request was not '
                      'approved. Contact HR for details.',
                );
            }
          },
        )
        // WHY onSubscribe callback: catches silent channel
        //   failures — without this errors are invisible
        .subscribe((status, [error]) {
          if (error != null) {
            AppLogger.error('leave_updates channel error: $error');
          } else {
            AppLogger.info(
              '✅ Listening to leave updates for $userId'
              ' | status: $status',
            );
          }
        });
  }

  // ── listenNewLeaveRequests() ──────────────────────────
  // PURPOSE: Admin gets notified when any employee
  //   submits a new leave request
  // WHY separate from listenLeaveUpdates: employee listens
  //   to UPDATE (admin decision), admin listens to INSERT
  //   (new application) — different events, different users
  void listenNewLeaveRequests() {
    _client
        .channel('admin_new_leave_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'leave_requests',
          callback: (payload) async {
            final userId = payload.newRecord['user_id'] as String?;
            final leaveType =
                payload.newRecord['leave_type'] as String? ?? 'Leave';
            final startDate = payload.newRecord['start_date'] as String? ?? '';

            // ── Fetch employee name ─────────────────────
            String employeeName = 'An employee';
            if (userId != null) {
              try {
                final profile = await _client
                    .from('profiles')
                    .select('full_name')
                    .eq('id', userId)
                    .single();
                employeeName = profile['full_name'] as String? ?? 'An employee';
              } catch (e) {
                AppLogger.error('Could not fetch name for leave notify: $e');
              }
            }

            AppLogger.debug('New leave request from $employeeName');

            _show(
              id: 4001,
              title: '📋 New Leave Request',
              body:
                  '$employeeName applied for '
                  '$leaveType starting $startDate.',
            );
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            AppLogger.error('admin_new_leave channel error: $error');
          } else {
            AppLogger.info(
              '✅ Admin listening for new leave requests'
              ' | status: $status',
            );
          }
        });
  }

  // ── listenAbsentSummary() ─────────────────────────────
  // PURPOSE: Admin gets notified when an employee marks
  //   absent for today
  void listenAbsentSummary({required bool isAdmin}) {
    if (!isAdmin) return;

    _client
        .channel('attendance_absent_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attendance',
          callback: (payload) async {
            final status = payload.newRecord['status'] as String?;
            if (status != 'absent') return;

            final now = DateTime.now();
            final dateStr =
                '${now.year}-'
                '${now.month.toString().padLeft(2, '0')}-'
                '${now.day.toString().padLeft(2, '0')}';

            try {
              final result = await _client
                  .from('attendance')
                  .select('id')
                  .eq('status', 'absent')
                  .eq('date', dateStr);

              final count = (result as List).length;
              _show(
                id: 3001,
                title: '📊 Attendance Alert',
                body: '$count employee(s) absent today.',
              );
            } catch (e) {
              AppLogger.error('listenAbsentSummary count failed: $e');
            }
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            AppLogger.error('absent_admin channel error: $error');
          } else {
            AppLogger.info(
              '✅ Admin absent listener active'
              ' | status: $status',
            );
          }
        });
  }

  // ── checkAndRemindCheckout() ──────────────────────────
  Future<void> checkAndRemindCheckout() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    if (now.hour < 18) return;

    try {
      final dateStr =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final result = await _client
          .from('attendance')
          .select('check_out_time, status')
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();

      final hasRecord = result != null;
      final checkedOut = result?['check_out_time'] != null;
      final isAbsent = result?['status'] == 'absent';

      if (hasRecord && !checkedOut && !isAbsent) {
        _show(
          id: 1001,
          title: '⏰ Don\'t forget to check out!',
          body:
              'You checked in today but haven\'t '
              'checked out yet.',
        );
      }
    } catch (e, st) {
      AppLogger.error('checkAndRemindCheckout failed', e, st);
    }
  }

  // ── dispose() ─────────────────────────────────────────
  Future<void> dispose() async {
    await _client.removeAllChannels();
    AppLogger.info('✅ Realtime channels removed');
  }

  // ── _show() ───────────────────────────────────────────
  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'face_attend_channel',
            'FaceAttend Notifications',
            channelDescription: 'Attendance reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: payload,
      );
      AppLogger.debug('🔔 Notification shown: $title');
    } catch (e, st) {
      AppLogger.error('_show notification failed', e, st);
    }
  }
}
