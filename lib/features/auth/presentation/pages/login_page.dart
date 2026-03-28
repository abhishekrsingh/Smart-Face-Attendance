import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../providers/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    // WHY: Always dispose controllers + focus nodes to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    // WHY: Validate all fields before API call — avoids unnecessary requests
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(authNotifierProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // WHY: Listen handles side effects (navigation/snackbar) separately
    // from build — avoids setState during build errors
    // Find this block and replace:
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.isLoginSuccess) {
        // ← changed from isSuccess
        ref.read(authNotifierProvider.notifier).resetState();
        context.go(AppRoutes.home);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ── Header ──────────────────────────────────────
                _buildHeader(isDark),

                const SizedBox(height: 40),

                // ── Error Banner ─────────────────────────────────
                if (authState.errorMessage != null)
                  _buildErrorBanner(authState.errorMessage!),

                // ── Email Field ──────────────────────────────────
                CustomTextField(
                  hint: AppStrings.emailHint,
                  prefixIcon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  focusNode: _emailFocus,
                  onEditingComplete: () =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    // WHY: Simple regex catches obvious typos before API call
                    if (!RegExp(
                      r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(v)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

                const SizedBox(height: 16),

                // ── Password Field ───────────────────────────────
                CustomTextField(
                  hint: AppStrings.passwordHint,
                  prefixIcon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  isPassword: true,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _submit,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

                const SizedBox(height: 28),

                // ── Login Button ─────────────────────────────────
                CustomButton(
                  label: AppStrings.loginButton,
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 24),

                // ── Signup Link ──────────────────────────────────
                _buildSignupLink(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.face_retouching_natural_rounded,
            color: Colors.white,
            size: 30,
          ),
        ).animate().scale(
          begin: const Offset(0.5, 0.5),
          duration: 600.ms,
          curve: Curves.elasticOut,
        ),

        const SizedBox(height: 24),

        Text(
          AppStrings.loginTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

        const SizedBox(height: 8),

        Text(
          'Sign in to mark your attendance',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.noAccount,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () {
            ref.read(authNotifierProvider.notifier).resetState();
            context.push(AppRoutes.signup);
          },
          child: const Text(
            AppStrings.signUp,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
