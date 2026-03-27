import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../../../../core/widgets/analysis/detected_faces_strip.dart';
import '../../../../core/widgets/analysis/face_compact_previews_row.dart';
import '../../../../core/widgets/analysis/face_swipe_comparison.dart';
import '../../../../core/widgets/analysis/result_metadata_panel.dart';
import '../controllers/result_controller.dart';

class FaceResultLayout extends StatelessWidget {
  const FaceResultLayout({super.key, required this.controller});

  final ResultController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final result = controller.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Result'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: tokens.spacingMd,
            children: [
              FaceSwipeComparison(
                originalPath: result.originalImagePath,
                processedPath: result.processedImagePath,
              ),
              FaceCompactPreviewsRow(
                originalPath: result.originalImagePath,
                processedPath: result.processedImagePath,
              ),
              DetectedFacesStrip(
                imagePath: result.processedImagePath,
                fallbackImagePath: result.originalImagePath,
                faceRects: result.faceRects,
                faceContours: result.faceContours,
                title: 'Face areas',
              ),
              ResultMetadataPanel(
                fileSize: result.fileSizeBytes,
                type: result.type.name,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          tokens.spacingLg,
          tokens.spacingSm,
          tokens.spacingLg,
          tokens.spacingLg,
        ),
        child: AppPrimaryButton.filled(
          label: 'Done',
          onPressed: controller.goHome,
          expand: true,
        ),
      ),
    );
  }
}
