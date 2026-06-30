import '../../../../core/enums/processing_type.dart';
import '../entities/detection_result.dart';

/// Detects the dominant content (face vs. text/document) in an image.
///
/// Implementations own the underlying ML/vision SDK; callers depend only on
/// this contract so the detector can be mocked in tests without a device.
abstract interface class ContentDetector {
  /// Normalizes EXIF orientation and detects content.
  ///
  /// [imagePath] is modified in-place (EXIF baked, possibly rotated).
  /// [preferredType] skips the other detection if set.
  Future<DetectionResult> detect({
    required String imagePath,
    ProcessingType? preferredType,
  });
}
