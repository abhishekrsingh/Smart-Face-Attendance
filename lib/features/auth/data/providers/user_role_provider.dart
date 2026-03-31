import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_provider.dart';

// ── userRoleProvider ──────────────────────────────────────────
// PURPOSE: Exposes the current user's role as a plain String?
//   so any widget can read it without touching AuthState directly
// WHY separate provider: widgets that only need the role don't
//   need to rebuild on every AuthState change — only on role
final userRoleProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);

  // WHY AuthStatus.authenticated check: replaces old
  //   "authState.value is! AuthAuthenticated" pattern —
  //   AuthAuthenticated class no longer exists, we use
  //   the AuthStatus enum instead
  if (authState.status != AuthStatus.authenticated) {
    return null;
  }

  return authState.role;
});

// ── isAdminProvider ───────────────────────────────────────────
// PURPOSE: Convenience bool — true if the current user is admin
// WHY convenience: avoids role == 'admin' checks scattered
//   across the widget tree
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == 'admin';
});

// ── currentUserIdProvider ─────────────────────────────────────
// PURPOSE: Exposes the logged-in user's Supabase UUID
// WHY needed: many data providers need userId without
//   importing Supabase directly into every widget
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);

  if (authState.status != AuthStatus.authenticated) {
    return null;
  }

  return authState.user?.id;
});
