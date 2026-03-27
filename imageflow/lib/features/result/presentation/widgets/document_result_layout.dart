import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/analysis/document_info_strip.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../../../../core/widgets/pdf/document_preview_panel.dart';
import '../controllers/result_controller.dart';

class DocumentResultLayout extends StatelessWidget {
  const DocumentResultLayout({super.key, required this.controller});

  final ResultController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Result'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacingLg),
                child: DocumentPreviewPanel(
                  hasPdf: controller.hasPdf,
                  pdfPath: result.pdfPath,
                  originalImagePath: result.originalImagePath,
                  processedImagePath: result.processedImagePath,
                  resolvePdfViewerController:
                      controller.resolvePdfViewerController,
                ),
              ),
            ),
            DocumentInfoStrip(
              fileSize: result.fileSizeBytes,
              extractedTextLength: result.extractedText?.length ?? 0,
              extractedText: result.extractedText,
              onViewExtractedText: controller.showExtractedTextSheet,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          tokens.spacingLg,
          tokens.spacingSm,
          tokens.spacingLg,
          tokens.spacingLg,
        ),
        child: controller.hasPdf
            ? Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton.outlined(
                      label: 'Open PDF',
                      icon: Icons.open_in_new,
                      onPressed: controller.openPdfExternally,
                      expand: true,
                    ),
                  ),
                  SizedBox(width: tokens.spacingSm),
                  Expanded(
                    child: AppPrimaryButton.filled(
                      label: 'Done',
                      onPressed: controller.goHome,
                      expand: true,
                    ),
                  ),
                ],
              )
            : AppPrimaryButton.filled(
                label: 'Done',
                onPressed: controller.goHome,
                expand: true,
              ),
      ),
    );
  }
}
