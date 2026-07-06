import 'dart:typed_data';

import '../models/normalized_corners.dart';

/// Detects document corners from a realtime camera frame via a native platform
/// implementation.
///
/// Implementations own the [MethodChannel]; callers depend only on this
/// contract so corner detection can be mocked in tests without a device.
/// (Still-image corner detection goes directly through the document_scan
/// package, not this seam.)
abstract interface class CornerDetector {
  /// Detects document corners from a raw camera frame (realtime).
  ///
  /// Returns [NormalizedCorners] with 0-1 coordinates, or null if no rectangle
  /// is found, detection is busy, or on error. **Deliberately returns null (not
  /// a Result) on error**: this is a per-frame hot path where the correct
  /// behavior is to drop the frame and continue — wrapping every frame in a
  /// Result would add allocation cost against the frame budget for no benefit.
  Future<NormalizedCorners?> detectCornersFromFrame({
    required int width,
    required int height,
    required int rotation,
    Uint8List? bytes,
    int bytesPerRow,
    Uint8List? yBytes,
    Uint8List? uBytes,
    Uint8List? vBytes,
    int yRowStride,
    int uvRowStride,
    int uvPixelStride,
    String format,
  });
}
