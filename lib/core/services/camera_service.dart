import 'package:camera/camera.dart';
import '../utils/app_logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras found on device');

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        // WHY: high resolution captures more facial detail
        // Better accuracy for embedding extraction vs medium
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // WHY: Auto-focus on face region improves detection accuracy
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);

      AppLogger.info('✅ Camera initialized: ${frontCamera.name}');
      AppLogger.debug(
        'Resolution: ${_controller!.value.previewSize?.width}'
        ' x ${_controller!.value.previewSize?.height}',
      );
    } catch (e, st) {
      AppLogger.error('Camera init failed', e, st);
      rethrow;
    }
  }

  Future<XFile?> captureImage() async {
    if (!isInitialized) return null;
    try {
      // WHY: Flash off prevents overexposure on face
      await _controller!.setFlashMode(FlashMode.off);

      // WHY: Small delay lets auto-exposure settle after flash off
      await Future.delayed(const Duration(milliseconds: 300));

      final image = await _controller!.takePicture();
      AppLogger.debug('📸 Captured: ${image.path}');
      return image;
    } catch (e) {
      AppLogger.error('Capture failed', e);
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
      _controller = null;
      AppLogger.info('📷 Camera disposed');
    } catch (e) {
      AppLogger.error('Camera dispose error', e);
    }
  }
}
