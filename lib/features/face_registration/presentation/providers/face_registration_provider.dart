import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/face_ml_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/face_repository.dart';

enum FaceRegistrationStatus {
  idle,
  cameraReady,
  detecting,
  processing,
  success,
  error,
}

class FaceRegistrationState {
  final FaceRegistrationStatus status;
  final String? errorMessage;
  final String? successMessage;

  const FaceRegistrationState({
    this.status = FaceRegistrationStatus.idle,
    this.errorMessage,
    this.successMessage,
  });

  FaceRegistrationState copyWith({
    FaceRegistrationStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return FaceRegistrationState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class FaceRegistrationNotifier extends Notifier<FaceRegistrationState> {
  final _cameraService = CameraService();
  final _mlService = FaceMLService();

  @override
  FaceRegistrationState build() => const FaceRegistrationState();

  CameraController? get cameraController => _cameraService.controller;

  Future<void> initialize() async {
    try {
      await _cameraService.initialize();
      await _mlService.initialize();
      state = state.copyWith(status: FaceRegistrationStatus.cameraReady);
    } catch (e) {
      state = state.copyWith(
        status: FaceRegistrationStatus.error,
        errorMessage: 'Camera init failed: $e',
      );
    }
  }

  Future<void> registerFace() async {
    if (state.status == FaceRegistrationStatus.processing) return;

    state = state.copyWith(status: FaceRegistrationStatus.detecting);

    try {
      // Step 1: Capture photo
      final image = await _cameraService.captureImage();
      if (image == null) throw Exception('Failed to capture image');

      state = state.copyWith(status: FaceRegistrationStatus.processing);

      // Step 2: Detect face
      final faces = await _mlService.detectFacesFromFile(image);
      if (faces.isEmpty) {
        state = state.copyWith(
          status: FaceRegistrationStatus.cameraReady,
          errorMessage: 'No face detected. Align your face in the oval.',
        );
        return;
      }

      // Step 3: Extract embedding
      final embedding = await _mlService.extractEmbedding(image);
      if (embedding == null) {
        state = state.copyWith(
          status: FaceRegistrationStatus.cameraReady,
          errorMessage: 'Could not process face. Try better lighting.',
        );
        return;
      }

      // Step 4: Upload image
      final imageUrl = await faceRepository.uploadFaceImage(image.path);

      // Step 5: Save embedding
      await faceRepository.saveFaceEmbedding(
        embedding: embedding,
        imageUrl: imageUrl,
      );

      state = state.copyWith(
        status: FaceRegistrationStatus.success,
        successMessage: 'Face registered successfully!',
      );
    } catch (e, st) {
      AppLogger.error('Registration failed', e, st);
      state = state.copyWith(
        status: FaceRegistrationStatus.error,
        errorMessage: 'Registration failed: $e',
      );
    }
  }

  Future<void> disposeResources() async {
    await _cameraService.dispose();
    await _mlService.dispose();
  }
}

final faceRegistrationProvider =
    NotifierProvider<FaceRegistrationNotifier, FaceRegistrationState>(
      FaceRegistrationNotifier.new,
    );
