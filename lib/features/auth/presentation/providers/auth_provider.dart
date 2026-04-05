import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/services/realtime_notification_service.dart';
import '../../../../data/remote/supabase_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? role;

  const AuthState({this.status = AuthStatus.initial, this.user, this.role});

  AuthState copyWith({AuthStatus? status, User? user, String? role}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        role: role ?? this.role,
      );
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  bool _listenersStarted = false;

  @override
  AuthState build() {
    _init();
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _init() async {
    // WHY removed currentUser check: it's a race condition —
    // Supabase hasn't restored the session from storage yet at
    // this point. initialSession is the CORRECT and ONLY place
    // to check session state on app start.
    await for (final s in SupabaseService.authStateStream) {
      AppLogger.debug('Auth event: ${s.event}');

      switch (s.event) {
        // ✅ THE FIX — initialSession fires on every cold start
        // with the restored session (or null if not logged in)
        case AuthChangeEvent.initialSession:
          if (s.session?.user != null) {
            final role = await _fetchRole(s.session!.user.id);
            state = AuthState(
              status: AuthStatus.authenticated,
              user: s.session!.user,
              role: role,
            );
            _startListeners(role);
            AppLogger.info('Auth: restored session, role=$role');
          } else {
            // No stored session → go to login
            state = const AuthState(status: AuthStatus.unauthenticated);
            AppLogger.info('Auth: no session → unauthenticated');
          }

        case AuthChangeEvent.signedIn:
          if (s.session?.user != null) {
            final role = await _fetchRole(s.session!.user.id);
            state = AuthState(
              status: AuthStatus.authenticated,
              user: s.session!.user,
              role: role,
            );
            _startListeners(role);
            AppLogger.info('Auth: signed in, role=$role');
          }

        case AuthChangeEvent.tokenRefreshed:
          // WHY only update user, not restart listeners:
          // token refresh is not a new login — role unchanged
          if (s.session?.user != null &&
              state.status == AuthStatus.authenticated) {
            state = state.copyWith(user: s.session!.user);
            AppLogger.debug('Token refreshed — session updated');
          }

        case AuthChangeEvent.signedOut:
          await RealtimeNotificationService.instance.dispose();
          _listenersStarted = false;
          state = const AuthState(status: AuthStatus.unauthenticated);
          AppLogger.info('Auth: signed out');

        default:
          AppLogger.debug('Auth: unhandled event ${s.event}');
          break;
      }
    }
  }

  void _startListeners(String? role) {
    if (_listenersStarted) {
      AppLogger.debug('Listeners already active — skipping');
      return;
    }
    _listenersStarted = true;

    final notif = RealtimeNotificationService.instance;
    notif.listenLeaveUpdates();

    if (role == 'admin') {
      notif.listenNewLeaveRequests();
    }

    notif.listenAbsentSummary(isAdmin: role == 'admin');
    AppLogger.info('✅ Realtime listeners started (role: $role)');
  }

  Future<String?> _fetchRole(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return data['role'] as String?;
    } catch (e) {
      AppLogger.error('_fetchRole failed: $e');
      return null;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
