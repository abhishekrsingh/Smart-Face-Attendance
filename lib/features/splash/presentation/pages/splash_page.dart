import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // WHY: Continuous pulse creates a "living" feel without Lottie dependency.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // WHY: Minimum 2.8s ensures branding is seen + auth state resolves.
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final authAsync = ref.read(authStateProvider);
    authAsync.when(
      data: (status) {
        if (status is AuthAuthenticated) {
          context.go(AppRoutes.home);
        } else {
          context.go(AppRoutes.login);
        }
      },
      // WHY: Safe fallback — any failure lands on login, not a dead screen
      loading: () => context.go(AppRoutes.login),
      error: (_, __) => context.go(AppRoutes.login),
    );
  }

  @override
  void dispose() {
    // WHY: Disposing animation controller prevents memory leaks
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 32),
              Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 8),
              Text(
                    AppStrings.tagline,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
              const Spacer(flex: 2),
              _buildLoadingDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Transform.scale(
              scale: _pulseAnimation.value * 1.4,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
            // Inner glow ring
            Transform.scale(
              scale: _pulseAnimation.value * 1.2,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child:
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              )
              .animate()
              .scale(
                begin: const Offset(0.3, 0.3),
                end: const Offset(1.0, 1.0),
                duration: 800.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 400.ms),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white54,
                shape: BoxShape.circle,
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .moveY(
              begin: 0,
              end: -8,
              delay: Duration(milliseconds: index * 180),
              duration: 400.ms,
              curve: Curves.easeOut,
            )
            .then()
            .moveY(begin: -8, end: 0, duration: 400.ms, curve: Curves.easeIn);
      }),
    ).animate().fadeIn(delay: 1200.ms, duration: 400.ms);
  }
}
