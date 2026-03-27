part of 'history_detail_page.dart';

class _HistoryDocumentDetailLayout extends StatelessWidget {
  const _HistoryDocumentDetailLayout({required this.controller});

  final HistoryDetailController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.history;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: Get.back,
        ),
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
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacingLg,
                tokens.spacingMd,
                tokens.spacingLg,
                tokens.spacingLg,
              ),
              child: Column(
                spacing: tokens.spacingMd,
                children: [
                  ResultMetadataPanel(
                    fileSize: result.fileSizeBytes,
                    type: result.type.name,
                    createdAt: result.createdAt,
                    showFileSize: false,
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
          ],
        ),
      ),
      bottomNavigationBar: controller.hasPdf
          ? SafeArea(
              minimum: EdgeInsets.fromLTRB(
                tokens.spacingLg,
                tokens.spacingSm,
                tokens.spacingLg,
                tokens.spacingLg,
              ),
              child: AppPrimaryButton.outlined(
                label: 'Open PDF',
                icon: Icons.open_in_new,
                onPressed: controller.openPdfExternally,
                expand: true,
              ),
            )
          : null,
    );
  }
}
