import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_logger.dart';

class SupabaseService {
  // ── Supabase project credentials ──────────────────────────────
  static const _url = 'https://rkxmezvfghgovdazkbjm.supabase.co';
  static const _anonKey = 'sb_publishable_lTvPSpqOjG9iji45z560xQ_OKQdHb2Z';

  // ── initialize() ──────────────────────────────────────────────
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(url: _url, anonKey: _anonKey);
      AppLogger.info('✅ Supabase initialised: $_url');
    } catch (e, st) {
      AppLogger.fatal('❌ Supabase init failed', e, st);
      rethrow;
    }
  }

  // ── client ────────────────────────────────────────────────────
  // WHY static getter: single access point across all repos
  static SupabaseClient get client => Supabase.instance.client;

  // ── currentUser ───────────────────────────────────────────────
  // WHY: auth_provider.dart checks session on app start
  static User? get currentUser => client.auth.currentUser;

  // ── authStateStream ───────────────────────────────────────────
  // WHY: auth_provider.dart listens for login/logout/refresh events
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  // ── supabaseUrl ───────────────────────────────────────────────
  // WHY exposed: profile_repository uses it to build upload URL
  static String get supabaseUrl => _url;
}
