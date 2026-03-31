import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/services/realtime_notification_service.dart';
import '../../../../data/remote/supabase_service.dart';

// ── Auth status enum ───────────────────────────────────────────
enum AuthStatus { initial, authenticated, unauthenticated }

// ── AuthState ─────────────────────────────────────────────────
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

// ── authStateProvider ─────────────────────────────────────────
// WHY NotifierProvider: StateNotifier + StateNotifierProvider
//   were deprecated and removed in Riverpod 2.x
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ── AuthNotifier ──────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  // WHY flag: Supabase fires tokenRefreshed right after
  //   signedIn — without this guard, _startListeners() runs
  //   twice, creating duplicate Realtime channels that fire
  //   double notifications
  bool _listenersStarted = false;

  // ── build() ───────────────────────────────────────────────
  // WHY build() not constructor: Riverpod 2.x Notifier uses
  //   build() as init point — state is settable here
  // WHY not await: build() must return synchronously —
  //   async init happens in background via _init()
  @override
  AuthState build() {
    _init();
    return const AuthState(status: AuthStatus.initial);
  }

  // ── _init() ───────────────────────────────────────────────
  // PURPOSE: Check existing session on app start + listen
  //   to all future auth state changes
  Future<void> _init() async {
    final current = SupabaseService.currentUser;

    if (current != null) {
      final role = await _fetchRole(current.id);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: current,
        role: role,
      );
      _startListeners(role);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // ── Listen to future auth changes ─────────────────────
    await for (final s in SupabaseService.authStateStream) {
      AppLogger.debug('Auth event: ${s.event}');

      switch (s.event) {
        case AuthChangeEvent.signedIn:
          // WHY only signedIn not tokenRefreshed: token
          //   refresh is not a new login — no need to restart
          //   listeners or re-fetch role on token refresh
          if (s.session?.user != null) {
            final role = await _fetchRole(s.session!.user.id);
            state = AuthState(
              status: AuthStatus.authenticated,
              user: s.session!.user,
              role: role,
            );
            _startListeners(role);
          }

        case AuthChangeEvent.tokenRefreshed:
          // WHY update user but NOT restart listeners:
          //   token refresh just refreshes the JWT —
          //   the user and role haven't changed, and we
          //   don't want to create duplicate channels
          if (s.session?.user != null &&
              state.status == AuthStatus.authenticated) {
            state = state.copyWith(user: s.session!.user);
            AppLogger.debug('Token refreshed — skipping listener restart');
          }

        case AuthChangeEvent.signedOut:
          // ── Clean up channels + reset everything ─────────
          await RealtimeNotificationService.instance.dispose();
          // WHY reset flag: next login must be able to
          //   start fresh listeners
          _listenersStarted = false;
          state = const AuthState(status: AuthStatus.unauthenticated);

        default:
          break;
      }
    }
  }

  // ── _startListeners() ────────────────────────────────────
  // PURPOSE: Start Realtime notification listeners once
  //   after a successful login
  void _startListeners(String? role) {
    if (_listenersStarted) {
      AppLogger.debug('Listeners already active — skipping');
      return;
    }
    _listenersStarted = true;

    final notif = RealtimeNotificationService.instance;

    // ── Employee: notified when admin acts on their leave ──
    notif.listenLeaveUpdates();

    // ── Admin: notified when employee submits new leave ────
    // WHY only admin: employees don't need to see others'
    //   leave applications
    if (role == 'admin') {
      notif.listenNewLeaveRequests(); // ← NEW
    }

    // ── Admin: notified when employee marks absent ─────────
    notif.listenAbsentSummary(isAdmin: role == 'admin');

    AppLogger.info('✅ Realtime listeners started (role: $role)');
  }

  // ── _fetchRole() ─────────────────────────────────────────
  // PURPOSE: Get employee role from profiles table
  // WHY needed: determines which Realtime channels to open
  //   and which screen to redirect to after login
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

  // ── signIn() ──────────────────────────────────────────────
  // WHY no setState: authStateStream in _init() fires the
  //   signedIn event automatically — state updates there
  Future<void> signIn({required String email, required String password}) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── signOut() ─────────────────────────────────────────────
  // WHY no setState: authStateStream fires signedOut event
  //   — dispose() + state update handled in _init()
  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
