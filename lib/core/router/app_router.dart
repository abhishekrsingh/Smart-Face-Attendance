import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Use the single source of truth for route paths ────────────
// WHY: Removed duplicate AppRoutes class that was defined here
//   AND in app_routes.dart — two classes with the same name
//   caused silent routing failures (signup tap did nothing)
import '../constants/app_routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_leave_page.dart';
import '../../features/admin/presentation/pages/admin_reports_page.dart';
import '../../features/leave/presentation/pages/leave_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/face_registration/presentation/pages/face_registration_page.dart';
import '../../features/attendance/presentation/pages/mark_attendance_page.dart';

// ── appRouterProvider ─────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash, // '/'
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final status = authState.status;
      final role = authState.role;
      final location = state.matchedLocation;

      // ── Still initialising → hold on splash ───────────────
      if (status == AuthStatus.initial) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // ── Not logged in ──────────────────────────────────────
      if (status == AuthStatus.unauthenticated) {
        // WHY allow signup: user must be able to navigate to
        //   /signup from login without being redirected back
        if (location == AppRoutes.login || location == AppRoutes.signup) {
          return null;
        }
        return AppRoutes.login;
      }

      // ── Logged in ──────────────────────────────────────────
      if (status == AuthStatus.authenticated) {
        // Redirect away from auth screens
        if (location == AppRoutes.splash ||
            location == AppRoutes.login ||
            location == AppRoutes.signup) {
          return role == 'admin' ? AppRoutes.admin : AppRoutes.home;
        }

        // Block employee from admin routes
        if (role != 'admin' &&
            (location == AppRoutes.admin ||
                location == AppRoutes.adminLeave ||
                location == AppRoutes.adminReports)) {
          return AppRoutes.home;
        }

        // Block admin from employee home
        if (role == 'admin' && location == AppRoutes.home) {
          return AppRoutes.admin;
        }
      }

      return null;
    },

    routes: [
      // ── Auth & splash ────────────────────────────────────────
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignupPage(), // ← register page
      ),

      // ── Employee ─────────────────────────────────────────────
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage()),
      GoRoute(
        path: AppRoutes.markAttendance,
        builder: (_, __) => const MarkAttendancePage(),
      ),
      GoRoute(
        path: AppRoutes.faceRegister,
        builder: (_, __) => const FaceRegistrationPage(),
      ),
      GoRoute(path: AppRoutes.leave, builder: (_, __) => const LeavePage()),
      GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfilePage()),

      // ── Admin ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, __) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.adminLeave,
        builder: (_, __) => const AdminLeavePage(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (_, __) => const AdminReportsPage(),
      ),
    ],
  );
});

// ── _RouterNotifier ───────────────────────────────────────────
// WHY: GoRouter.refreshListenable needs a ChangeNotifier —
//   Riverpod providers are not ChangeNotifiers natively
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }
}
