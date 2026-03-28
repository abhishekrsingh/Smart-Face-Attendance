// ============================================================
// CameraPreviewWidget
// PURPOSE: Reusable wrapper around Flutter's CameraPreview.
// Currently face_registration_page.dart uses CameraPreview
// directly — this widget is kept for future reuse in other
// pages that need a standardized camera preview layout.
// ============================================================

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // WHY isInitialized check: accessing CameraPreview before
    // controller is initialized throws StateError
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // WHY SizedBox.expand: fills all available space in parent
    // Stack/Column without needing explicit width/height
    return SizedBox.expand(child: CameraPreview(controller));
  }
}
