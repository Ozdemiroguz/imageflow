import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../analysis/fullscreen_image_view.dart';
import '../analysis/image_comparison.dart';
import '../analysis/original_preview_card.dart';
import 'pdf_viewer.dart';
import 'pdf_viewer_controller.dart';

class DocumentPreviewPanel extends StatelessWidget {
  const DocumentPreviewPanel({
    super.key,
    required this.hasPdf,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.resolvePdfViewerController,
    this.pdfPath,
  });

  final bool hasPdf;
  final String? pdfPath;
  final String originalImagePath;
  final String processedImagePath;
  final PdfViewerController Function(String pdfPath) resolvePdfViewerController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (hasPdf && pdfPath != null && pdfPath!.trim().isNotEmpty) {
      final controller = resolvePdfViewerController(pdfPath!);
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              child: PdfViewer(controller: controller),
            ),
          ),
          Positioned(
            right: tokens.spacingMd,
            bottom: tokens.spacingMd,
            child: OriginalPreviewCard(
              imagePath: originalImagePath,
              onTap: () => FullscreenImageView.show(
                context,
                imagePath: originalImagePath,
                label: 'Original',
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: ImageComparison(
        originalPath: originalImagePath,
        processedPath: processedImagePath,
      ),
    );
  }
}
