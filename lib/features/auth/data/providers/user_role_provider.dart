// ============================================================
// user_role_provider.dart
// PURPOSE: Fetches current logged-in user's role from
// Supabase profiles table.
//
// WHY watch authStateProvider: re-runs automatically on
// every auth change (login/logout) — ensures role is always
// fresh and never stale-cached from previous session.
//
// WHY FutureProvider: role comes from async Supabase call
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final userRoleProvider = FutureProvider<String?>((ref) async {
  // WHY watch: re-evaluates every time auth state changes —
  // login/logout/token refresh all trigger fresh role fetch
  final authState = ref.watch(authStateProvider);

  // WHY check AuthAuthenticated: don't hit DB if not logged in
  // avoids unnecessary Supabase calls on splash/login screens
  if (authState.value is! AuthAuthenticated) return null;

  // Get current user from active Supabase session
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    // WHY .single(): one user = one profile row guaranteed
    final data = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    return data['role'] as String?;
  } catch (e) {
    // WHY catch: if profile row missing → default to employee
    // prevents crash on first-time users before profile created
    return 'employee';
  }
});
