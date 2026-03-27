part of 'history_detail_page.dart';

class _HistoryFaceDetailLayout extends StatelessWidget {
  const _HistoryFaceDetailLayout({required this.controller});

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
                createdAt: result.createdAt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
