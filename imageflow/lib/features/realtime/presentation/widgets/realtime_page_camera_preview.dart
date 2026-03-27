import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../controllers/realtime_camera_controller.dart';
import '../enums/realtime_preview_target.dart';
import 'realtime_document_overlay_painter.dart';
import 'realtime_face_overlay_painter.dart';

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
                Transform.flip(
                  flipX: controller.isFrontCamera,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(cameraController),
                      Obx(() {
                        final faces = controller.faceRects.toList(
                          growable: false,
                        );
                        final tokens = context.tokens;
                        return RepaintBoundary(
                          child: CustomPaint(
                            painter: RealtimeFaceOverlayPainter(
                              faces: faces,
                              tokens: tokens,
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
                    ],
                  ),
                ),
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

