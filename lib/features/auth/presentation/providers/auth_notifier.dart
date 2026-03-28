import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/remote/auth_repository.dart';

class AuthFormState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final bool isLoginSuccess; // WHY: Only true after LOGIN — triggers home nav
  final bool
  isSignupSuccess; // WHY: Only true after SIGNUP — triggers login nav

  const AuthFormState({
    this.isLoading = false,
    this.errorMessage,
    this.isLoginSuccess = false,
    this.isSignupSuccess = false,
  });

  AuthFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isLoginSuccess,
    bool? isSignupSuccess,
  }) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isLoginSuccess: isLoginSuccess ?? this.isLoginSuccess,
      isSignupSuccess: isSignupSuccess ?? this.isSignupSuccess,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    isLoginSuccess,
    isSignupSuccess,
  ];
}

class AuthNotifier extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthFormState(isLoading: true);
    try {
      await authRepository.signIn(email: email, password: password);
      // WHY: Only login sets isLoginSuccess — this is what navigates to home
      state = const AuthFormState(isLoginSuccess: true);
    } catch (e) {
      AppLogger.error('SignIn failed: $e');
      state = AuthFormState(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AuthFormState(isLoading: true);
    try {
      await authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      // WHY: After signup, sign out immediately so user must login manually.
      // This enforces credential verification before accessing the app.
      await authRepository.signOut();

      // WHY: isSignupSuccess → navigates to LOGIN, not home
      state = const AuthFormState(isSignupSuccess: true);
    } catch (e) {
      AppLogger.error('SignUp failed: $e');
      state = AuthFormState(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void resetState() => state = const AuthFormState();
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthFormState>(
  AuthNotifier.new,
);
