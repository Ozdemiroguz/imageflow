import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../controllers/realtime_camera_controller.dart';
import '../enums/realtime_preview_target.dart';
import 'realtime_document_overlay_painter.dart';
import 'realtime_face_overlay_painter.dart';
import 'realtime_object_overlay_painter.dart';

part 'realtime_page_camera_preview_expanded_panel.dart';

class RealtimeCameraPreview extends StatelessWidget {
  const RealtimeCameraPreview({required this.controller, super.key});

  final RealtimeCameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasCameraPermission.value) {
      return const SizedBox.shrink();
    }

    final cameraController = controller.cameraController;
    if (cameraController == null) {
      return const SizedBox.shrink();
    }
    try {
      if (!cameraController.value.isInitialized ||
          cameraController.value.previewSize == null) {
        return const SizedBox.shrink();
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: cameraController.value.previewSize!.height,
            height: cameraController.value.previewSize!.width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Only the camera image is mirrored on the front camera (so the
                // user sees themselves as in a mirror). Detection overlays are
                // NOT inside this flip: their coordinates come from the
                // un-mirrored frame, so flipping them too would put the boxes on
                // the wrong side. They are drawn in the un-flipped space below.
                Transform.flip(
                  flipX: controller.isFrontCamera,
                  child: CameraPreview(cameraController),
                ),
                Obx(() {
                  final faces = controller.faceRects.toList(growable: false);
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: RealtimeFaceOverlayPainter(
                        faces: faces,
                        tokens: context.tokens,
                      ),
                    ),
                  );
                }),
                Obx(
                  () => RepaintBoundary(
                    child: CustomPaint(
                      painter: RealtimeDocumentOverlayPainter(
                        corners: controller.documentCorners.value,
                        tokens: context.tokens,
                      ),
                    ),
                  ),
                ),
                Obx(() {
                  final objects = controller.detectedObjects.toList(
                    growable: false,
                  );
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: RealtimeObjectOverlayPainter(
                        objects: objects,
                        tokens: context.tokens,
                      ),
                    ),
                  );
                }),
                RealtimeLiveQuarterPreviewOverlay(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RealtimeLiveQuarterPreviewOverlay extends StatelessWidget {
  const RealtimeLiveQuarterPreviewOverlay({
    required this.controller,
    super.key,
  });

  final RealtimeCameraController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final target = controller.expandedPreviewTarget.value;
      if (target == null) return const SizedBox.shrink();
      return _RealtimeExpandedLivePanel(
        controller: controller,
        isFace: target == RealtimePreviewTarget.face,
      );
    });
  }
}
