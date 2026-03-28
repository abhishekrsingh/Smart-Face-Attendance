// ============================================================
// app_router.dart
// PURPOSE: All app routes defined here.
//
// FLOW:
//   Splash → check auth + role
//   ├── Not logged in       → /login
//   ├── logged in + admin   → /admin  (full screen, no nav bar)
//   └── logged in + employee → /home  (bottom nav shell)
//
// WHY _RouterNotifier: watches BOTH authStateProvider AND
// userRoleProvider — any change triggers redirect re-check.
//
// WHY StatefulShellRoute: each tab keeps its own navigation
// stack alive — switching tabs doesn't reload pages.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/screens/history_screen.dart';
import '../../features/auth/data/providers/user_role_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../constants/app_routes.dart';
import '../navigation/app_shell.dart';
import '../utils/app_logger.dart';
import '../../features/face_registration/presentation/pages/face_registration_page.dart';
import '../../features/attendance/presentation/pages/mark_attendance_page.dart';

// ── Navigator Keys ─────────────────────────────────────────────
// WHY: StatefulShellRoute needs unique key per branch so each
// tab has its own independent navigation stack
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _historyNavKey = GlobalKey<NavigatorState>(debugLabel: 'history');
final _profileNavKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

// ── RouterNotifier ─────────────────────────────────────────────
// WHY: Bridges Riverpod with GoRouter's refreshListenable.
// Watches BOTH auth + role — either change triggers redirect()
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    // Re-check routes when auth state changes (login/logout)
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    // Re-check routes when role finishes loading from Supabase
    _ref.listen(userRoleProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,

    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // Auth still resolving → stay on splash
      if (authAsync.isLoading) return AppRoutes.splash;

      final status = authAsync.asData?.value;
      final isAuthenticated = status is AuthAuthenticated;
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnAuth =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;
      final isOnAdmin = state.matchedLocation == AppRoutes.admin;

      // ── Not authenticated + protected route → login ────────
      if (!isAuthenticated && !isOnAuth && !isOnSplash) {
        AppLogger.info('Router → /login');
        return AppRoutes.login;
      }

      // ── Authenticated → enforce role-based routing ─────────
      if (isAuthenticated) {
        final roleAsync = ref.read(userRoleProvider);

        // WHY: Role still fetching from Supabase → hold on splash
        // notifier fires again once role loads, re-runs redirect
        if (roleAsync.isLoading) return AppRoutes.splash;

        final role = roleAsync.asData?.value;

        // Admin on any non-admin route → push to admin dashboard
        if (role == 'admin' && !isOnAdmin) {
          AppLogger.info('Router → /admin (admin role detected)');
          return AppRoutes.admin;
        }

        // Non-admin trying to access admin route → push to home
        if (role != 'admin' && isOnAdmin) {
          AppLogger.info('Router → /home (not an admin)');
          return AppRoutes.home;
        }

        // Employee on auth/splash → send to home (bottom nav)
        if ((isOnAuth || isOnSplash) && role != 'admin') {
          AppLogger.info('Router → /home (employee)');
          return AppRoutes.home;
        }
      }

      return null;
    },

    routes: [
      // ── Public routes (no bottom nav) ──────────────────────
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignupPage()),

      // ── Admin route (full screen, no bottom nav) ───────────
      // WHY parentNavigatorKey _rootNavigatorKey: sits outside
      // the shell — admin sees NO bottom navigation bar
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.admin,
        builder: (_, __) => const AdminDashboardPage(),
      ),

      // ── Full screen routes (camera, no bottom nav) ─────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.faceRegister,
        builder: (_, __) => const FaceRegistrationPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.markAttendance,
        builder: (_, __) => const MarkAttendancePage(),
      ),

      // ── Employee shell (bottom nav) ────────────────────────
      // WHY StatefulShellRoute.indexedStack: preserves each
      // tab's state — no reload when switching between tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // AppShell provides the bottom navigation bar wrapper
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0 → Home tab
          StatefulShellBranch(
            navigatorKey: _homeNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),

          // Branch 1 → History tab
          StatefulShellBranch(
            navigatorKey: _historyNavKey,
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, __) => const HistoryScreen(),
              ),
            ],
          ),

          // Branch 2 → Profile tab
          StatefulShellBranch(
            navigatorKey: _profileNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
