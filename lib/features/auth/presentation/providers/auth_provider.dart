import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/remote/supabase_service.dart';

// WHY: Sealed class forces every consumer to handle all auth states.
// No accidental null-checks that silently miss the "loading" case.
sealed class AuthStatus {
  const AuthStatus();
}

class AuthInitial extends AuthStatus {
  const AuthInitial();
}

class AuthAuthenticated extends AuthStatus {
  final User user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthStatus {
  const AuthUnauthenticated();
}

// WHY: StreamProvider converts Supabase's auth stream into reactive
// Riverpod state — the router refreshes on every emit automatically.
final authStateProvider = StreamProvider<AuthStatus>((ref) async* {
  // Emit immediately so splash doesn't wait for first stream event
  final current = SupabaseService.currentUser;
  if (current != null) {
    AppLogger.info('🔑 Session restored: ${current.email}');
    yield AuthAuthenticated(current);
  } else {
    yield const AuthUnauthenticated();
  }

  // Then listen for runtime changes (login, logout, token refresh)
  await for (final state in SupabaseService.authStateStream) {
    AppLogger.debug('Auth event: ${state.event}');
    final user = state.session?.user;
    if (user != null) {
      yield AuthAuthenticated(user);
    } else {
      yield const AuthUnauthenticated();
    }
  }
});
