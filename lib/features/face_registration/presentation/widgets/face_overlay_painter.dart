import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

// WHY: Larger oval covers full face including forehead and chin.
// Previous oval was too small — cropped embedding lost important features.
class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  final double animationValue;

  const FaceOverlayPainter({
    required this.faceDetected,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // WHY: Increased from 0.65/0.45 to 0.78/0.60
    // Larger oval = full face (forehead to chin) fits inside guide
    final ovalW = size.width * 0.78;
    final ovalH = size.height * 0.60;

    final ovalRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: ovalW,
      height: ovalH,
    );

    // ── Dark overlay with oval cutout ──────────────────────────────
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // ── Animated oval border ───────────────────────────────────────
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = faceDetected
            ? AppColors.present
            : Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // ── Corner brackets ────────────────────────────────────────────
    _drawBrackets(canvas, ovalRect);

    // ── Scanning line animation ────────────────────────────────────
    if (!faceDetected) {
      _drawScanLine(canvas, size, ovalRect);
    }
  }

  void _drawBrackets(Canvas canvas, Rect oval) {
    final paint = Paint()
      ..color = faceDetected ? AppColors.present : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const bl = 28.0;
    final l = oval.left;
    final r = oval.right;
    final t = oval.top;
    final b = oval.bottom;

    // Top-left bracket
    canvas.drawLine(Offset(l, t + bl), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + bl, t), paint);
    // Top-right bracket
    canvas.drawLine(Offset(r - bl, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + bl), paint);
    // Bottom-left bracket
    canvas.drawLine(Offset(l, b - bl), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + bl, b), paint);
    // Bottom-right bracket
    canvas.drawLine(Offset(r - bl, b), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - bl), paint);
  }

  void _drawScanLine(Canvas canvas, Size size, Rect oval) {
    // WHY: Animated scan line gives visual feedback that camera is active
    // Moves top → bottom continuously using animationValue [0,1]
    final scanY = oval.top + (oval.height * animationValue);

    // Only draw within the oval bounds
    if (scanY < oval.bottom) {
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.primary.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(oval.left, scanY - 2, oval.width, 4))
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(oval.left, scanY - 2, oval.width, 4),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter old) =>
      old.faceDetected != faceDetected || old.animationValue != animationValue;
}
