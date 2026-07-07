import '../../../../core/models/normalized_corners.dart';
import '../entities/recognized_text_data.dart';

/// The geometry outcome of a [DocumentCropper.processDocument] run — whether the
/// output image is spatially different from the source, or only recolored.
///
/// Callers use this to decide whether a second OCR pass on the processed image
/// can add anything: when the geometry is unchanged (only a whole-image filter
/// was applied), the processed pixels carry the same text layout the source
/// already OCR'd, so re-OCR is wasted work.
enum DocumentCropOutcome {
  /// A perspective warp (4-corner) or an axis-aligned text-block crop changed
  /// the image's geometry — re-OCR on the clean image may read better.
  geometryChanged,

  /// No crop/warp happened (no corners, no text blocks) — only a whole-image
  /// enhance filter was applied, so the layout matches the source.
  filterOnly,
}

/// Crops, rectifies, and enhances a document image, writing the result to disk.
///
/// Implementations own the corner-detection + image pipeline; callers depend
/// only on this contract so the cropper can be mocked in tests. The contract is
/// plugin-free — text geometry is passed as [RecognizedTextData], not an ML Kit
/// type.
abstract interface class DocumentCropper {
  /// Processes a document image: detect corners → crop/rectify → filter → save.
  ///
  /// When [corners] is provided (e.g. from a manual corner-adjustment screen),
  /// detection is skipped and the image is cropped with exactly those corners.
  /// When it's null, corners are detected automatically as before.
  ///
  /// Returns whether the output geometry changed (see [DocumentCropOutcome]).
  Future<DocumentCropOutcome> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedTextData? recognizedText,
    NormalizedCorners? corners,
  });
}
