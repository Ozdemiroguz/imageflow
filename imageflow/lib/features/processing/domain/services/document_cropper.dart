import '../entities/recognized_text_data.dart';

/// Crops, rectifies, and enhances a document image, writing the result to disk.
///
/// Implementations own the corner-detection + image pipeline; callers depend
/// only on this contract so the cropper can be mocked in tests. The contract is
/// plugin-free — text geometry is passed as [RecognizedTextData], not an ML Kit
/// type.
abstract interface class DocumentCropper {
  /// Processes a document image: detect corners → crop/rectify → filter → save.
  Future<void> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedTextData? recognizedText,
  });
}
