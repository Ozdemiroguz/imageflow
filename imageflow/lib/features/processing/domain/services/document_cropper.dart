import '../../../../core/models/normalized_corners.dart';
import '../entities/recognized_text_data.dart';

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
  Future<void> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedTextData? recognizedText,
    NormalizedCorners? corners,
  });
}
