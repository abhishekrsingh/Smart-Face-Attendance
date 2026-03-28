import 'package:supabase_flutter/supabase_flutter.dart';
import '../../env/env.dart';
import '../../core/utils/app_logger.dart';

// WHY: Single accessor prevents scattered Supabase.instance calls.
// Easy to mock in unit tests by replacing this service.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;

  // WHY: Stream-based auth state lets the router react to
  // login/logout/token-refresh events without manual polling.
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // WHY: PKCE flow is more secure than implicit for mobile OAuth
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    AppLogger.info('✅ Supabase initialised');
  }
}
