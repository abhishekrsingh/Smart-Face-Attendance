import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_logger.dart';
import 'supabase_service.dart';

// WHY: Repository pattern isolates all Supabase auth calls from UI.
// If we ever swap auth providers, only this file changes.
class AuthRepository {
  final _client = SupabaseService.client;

  /// Sign in with email + password
  /// Returns User on success, throws on failure
  Future<User> signIn({required String email, required String password}) async {
    try {
      AppLogger.info('🔐 Signing in: $email');
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed — no user returned');
      }

      AppLogger.info('✅ Sign in success: ${response.user!.email}');
      return response.user!;
    } on AuthException catch (e) {
      // WHY: AuthException has user-friendly messages from Supabase
      AppLogger.error('Auth error: ${e.message}');
      throw Exception(_mapAuthError(e.message));
    } catch (e) {
      AppLogger.error('Sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email + password + full name
  Future<User> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      AppLogger.info('📝 Signing up: $email');
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // WHY: Pass name in metadata so the trigger can use it
        // when auto-creating the profile row
        data: {'full_name': fullName.trim()},
      );

      if (response.user == null) {
        throw Exception('Sign up failed — no user returned');
      }

      AppLogger.info('✅ Sign up success: ${response.user!.email}');
      return response.user!;
    } on AuthException catch (e) {
      AppLogger.error('Auth error: ${e.message}');
      throw Exception(_mapAuthError(e.message));
    } catch (e) {
      AppLogger.error('Sign up error: $e');
      rethrow;
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      AppLogger.info('👋 Signed out');
    } catch (e) {
      AppLogger.error('Sign out error: $e');
      rethrow;
    }
  }

  // WHY: Map Supabase raw error messages to user-friendly strings
  // Raw messages like "Invalid login credentials" are confusing to users
  String _mapAuthError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    } else if (msg.contains('email not confirmed')) {
      return 'Please verify your email first.';
    } else if (msg.contains('user already registered')) {
      return 'An account with this email already exists.';
    } else if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    } else if (msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    } else if (msg.contains('email rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return message;
  }
}

// WHY: Global instance — avoids recreating repository on every widget rebuild
final authRepository = AuthRepository();
