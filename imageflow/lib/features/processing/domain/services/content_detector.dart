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
  ///
  /// [allowRotationFallback] (default true): when no content is found at the
  /// upright orientation, the detector rotates the file 90/180/270 in place to
  /// find text and leaves it in the matching orientation (reported via
  /// [DetectionResult.appliedRotation]). Callers that already know the document
  /// geometry — e.g. the user supplied manual corners in upright space — must
  /// pass `false`, otherwise a pre-crop rotation would move the pixels out from
  /// under those corners and the warp would sample the wrong region.
  Future<DetectionResult> detect({
    required String imagePath,
    ProcessingType? preferredType,
    bool allowRotationFallback = true,
  });
}
