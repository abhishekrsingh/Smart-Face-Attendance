// ignore_for_file: use_build_context_synchronously

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/face_registration_provider.dart';
import '../widgets/face_overlay_painter.dart';

class FaceRegistrationPage extends ConsumerStatefulWidget {
  const FaceRegistrationPage({super.key});

  @override
  ConsumerState<FaceRegistrationPage> createState() =>
      _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends ConsumerState<FaceRegistrationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  // WHY: Save notifier reference in initState while ref is still safe.
  // Using ref inside dispose() throws StateError in Riverpod 2.x
  // because widget is unmounted before dispose completes.
  late FaceRegistrationNotifier _notifier;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // WHY: Capture reference here — ref is guaranteed safe in initState
    _notifier = ref.read(faceRegistrationProvider.notifier);

    // WHY: addPostFrameCallback ensures widget tree is fully built
    // before camera init triggers internal setState calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier.initialize();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    // WHY: Using saved _notifier — safe even after widget unmounts
    _notifier.disposeResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceRegistrationProvider);

    // WHY: Use saved _notifier instead of ref.read — consistent + safe
    final notifier = _notifier;

    ref.listen(faceRegistrationProvider, (_, next) {
      if (next.status == FaceRegistrationStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? 'Face registered!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go(AppRoutes.home);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Register Face',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCamera(state, notifier)),
            _buildControls(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera(
    FaceRegistrationState state,
    FaceRegistrationNotifier notifier,
  ) {
    final controller = notifier.cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white60, fontFamily: 'Poppins'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _scanController,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(child: CameraPreview(controller)),
          CustomPaint(
            painter: FaceOverlayPainter(
              faceDetected: state.status == FaceRegistrationStatus.success,
              animationValue: _scanController.value,
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(bottom: 20, child: _buildStatusChip(state)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(FaceRegistrationState state) {
    String msg = 'Align your face in the oval';
    Color color = Colors.white70;

    switch (state.status) {
      case FaceRegistrationStatus.detecting:
        msg = '🔍 Detecting face...';
        color = AppColors.warning;
        break;
      case FaceRegistrationStatus.processing:
        msg = '⚙️ Processing...';
        color = AppColors.info;
        break;
      case FaceRegistrationStatus.success:
        msg = '✅ Registered!';
        color = AppColors.success;
        break;
      case FaceRegistrationStatus.error:
        msg = state.errorMessage ?? 'Error';
        color = AppColors.error;
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: color,
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate(key: ValueKey(state.status)).fadeIn(duration: 300.ms);
  }

  Widget _buildControls(
    FaceRegistrationState state,
    FaceRegistrationNotifier notifier,
  ) {
    final isBusy =
        state.status == FaceRegistrationStatus.detecting ||
        state.status == FaceRegistrationStatus.processing;

    final canCapture =
        state.status == FaceRegistrationStatus.cameraReady ||
        state.status == FaceRegistrationStatus.error;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          const Text(
            'Look directly at the camera\nEnsure good lighting on your face',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 20),

          CustomButton(
            label: isBusy ? 'Processing...' : 'Capture & Register Face',
            isLoading: isBusy,
            icon: Icons.face_retouching_natural_rounded,
            onPressed: canCapture ? () => notifier.registerFace() : null,
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Colors.white30,
                fontFamily: 'Poppins',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
