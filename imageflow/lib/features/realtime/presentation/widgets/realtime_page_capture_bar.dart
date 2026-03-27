import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../controllers/realtime_camera_controller.dart';
import '../enums/realtime_preview_target.dart';
import 'realtime_result_panels.dart';

class RealtimeCaptureBar extends StatelessWidget {
  const RealtimeCaptureBar({required this.controller, super.key});

  final RealtimeCameraController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tokens.spacingXl,
        tokens.spacingMd,
        tokens.spacingXl,
        tokens.spacingXl + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final isExpanded =
                  controller.expandedPreviewTarget.value ==
                  RealtimePreviewTarget.face;
              return RealtimeResultPanelCard(
                title: 'Face',
                status: controller.faceStatus.value,
                icon: Icons.face_retouching_natural_outlined,
                bytes: controller.facePreviewBytes.value,
                onTap: () => controller.toggleExpandedPreviewTarget(
                  RealtimePreviewTarget.face,
                ),
                isExpanded: isExpanded,
              );
            }),
          ),
          SizedBox(width: tokens.spacingSm),
          Expanded(
            child: Obx(() {
              final isExpanded =
                  controller.expandedPreviewTarget.value ==
                  RealtimePreviewTarget.document;
              return RealtimeResultPanelCard(
                title: 'Document',
                status: controller.documentStatus.value,
                icon: Icons.description_outlined,
                bytes: controller.documentPreviewBytes.value,
                onTap: () => controller.toggleExpandedPreviewTarget(
                  RealtimePreviewTarget.document,
                ),
                isExpanded: isExpanded,
              );
            }),
          ),
        ],
      ),
    );
  }
}
