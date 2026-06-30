import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Crops, rectifies, and enhances a document image, writing the result to disk.
///
/// Implementations own the corner-detection + image pipeline; callers depend
/// only on this contract so the cropper can be mocked in tests.
// TODO(phase2): replace [RecognizedText] with a plugin-free text geometry type
// so this domain contract no longer imports an ML Kit package (AUDIT N2).
abstract interface class DocumentCropper {
  /// Processes a document image: detect corners → crop/rectify → filter → save.
  Future<void> processDocument({
    required String sourcePath,
    required String targetPath,
    RecognizedText? recognizedText,
  });
}
