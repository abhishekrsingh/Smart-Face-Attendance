import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/app_logger.dart';

class FaceMLService {
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;

  // WHY: Read from model at runtime — handles any FaceNet variant size
  int _inputSize = 160;

  bool get isInitialized => _interpreter != null;

  Future<void> initialize() async {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          // WHY: classification gives eye open probability for anti-spoof
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.15,
        ),
      );

      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      // WHY: Dynamically read input shape from model
      // Works for both 112x112 (MobileFaceNet) and 160x160 (FaceNet)
      final inputShape = _interpreter!.getInputTensor(0).shape;
      _inputSize = inputShape[1]; // [1, H, W, 3] → H is index 1

      AppLogger.info('✅ FaceML initialized');
      AppLogger.info(
        'Model → input: $inputShape, '
        'output: ${_interpreter!.getOutputTensor(0).shape}',
      );
      AppLogger.info('Input size detected: $_inputSize x $_inputSize');
    } catch (e, st) {
      AppLogger.error('FaceML init failed', e, st);
      rethrow;
    }
  }

  /// Detect faces from captured image file
  Future<List<Face>> detectFacesFromFile(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);
      AppLogger.debug('Faces detected: ${faces.length}');
      return faces;
    } catch (e) {
      AppLogger.error('Face detection failed', e);
      return [];
    }
  }

  /// Full pipeline: detect → crop → normalise → infer → return embedding
  Future<List<double>?> extractEmbedding(XFile imageFile) async {
    try {
      // Step 1: Detect face bounding box
      final faces = await detectFacesFromFile(imageFile);
      if (faces.isEmpty) {
        AppLogger.warning('No face found for embedding');
        return null;
      }

      // WHY: Use largest face = person closest to camera
      final face = faces.reduce(
        (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b,
      );

      // Step 2: Decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Image decode failed');

      // Step 3: Crop face with proportional padding
      // WHY: 35% proportional padding captures forehead, chin, and ears.
      // Fixed pixel padding was too small on high-res images.
      const paddingPercent = 0.35;
      final box = face.boundingBox;
      final padW = (box.width * paddingPercent).toInt();
      final padH = (box.height * paddingPercent).toInt();

      final x = max(0, box.left.toInt() - padW);
      final y = max(0, box.top.toInt() - padH);
      final w = min(decoded.width - x, box.width.toInt() + padW * 2);
      final h = min(decoded.height - y, box.height.toInt() + padH * 2);

      AppLogger.debug(
        'Face crop → x:$x y:$y w:$w h:$h '
        '(pad: ${padW}x$padH)',
      );

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

      // Step 4: Resize to model input size (dynamic — 112 or 160)
      final resized = img.copyResize(
        cropped,
        width: _inputSize,
        height: _inputSize,
      );

      // Step 5: Build float32 input tensor [1, H, W, 3]
      final input = _buildInputTensor(resized);

      // Step 6: Prepare output tensor [1, embeddingSize]
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final embeddingSize = outputShape[1];
      final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));

      // Step 7: Run inference
      _interpreter!.run(input, output);

      final embedding = List<double>.from(output[0]);
      AppLogger.debug('✅ Embedding: ${embedding.length} dims');
      return embedding;
    } catch (e, st) {
      AppLogger.error('Embedding extraction failed', e, st);
      return null;
    }
  }

  /// Build normalised float32 tensor from resized image
  List<List<List<List<double>>>> _buildInputTensor(img.Image image) {
    // WHY: TFLite expects [batch=1, height, width, channels=3]
    // Normalise [0,255] → [-1.0, 1.0] as FaceNet was trained
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (pixel.r / 127.5) - 1.0,
            (pixel.g / 127.5) - 1.0,
            (pixel.b / 127.5) - 1.0,
          ];
        }),
      ),
    );
  }

  // ── Similarity Metrics ────────────────────────────────────────────

  /// Cosine similarity → range [-1, 1], higher = more similar
  static double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Euclidean distance → lower = more similar
  static double euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }

  /// Combined check — both thresholds must pass to confirm identity
  static bool isSamePerson(List<double> stored, List<double> current) {
    final cosine = cosineSimilarity(stored, current);
    final euclidean = euclideanDistance(stored, current);

    AppLogger.debug(
      'Face match → cosine: ${cosine.toStringAsFixed(3)}, '
      'euclidean: ${euclidean.toStringAsFixed(3)}',
    );

    // WHY: Relaxed from (> 0.80, < 0.60) to (> 0.75, < 0.90)
    // MobileFaceNet 192-dim model scores 0.81 cosine for same person
    // with slight lighting/angle variation — old thresholds were too strict.
    // Cosine > 0.75 = strong match for 192-dim embeddings.
    // Euclidean < 0.90 = handles real-world variation safely.
    // Different persons typically score cosine < 0.50 — still secure.
    return cosine > 0.75 && euclidean < 0.90;
  }

  Future<void> dispose() async {
    await _faceDetector?.close();
    _interpreter?.close();
    AppLogger.info('FaceML disposed');
  }
}
