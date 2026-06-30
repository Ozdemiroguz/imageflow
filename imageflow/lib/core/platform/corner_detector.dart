import 'dart:typed_data';

import '../models/document_corners.dart';
import '../models/normalized_corners.dart';

/// Detects document corners via a native platform implementation.
///
/// Implementations own the [MethodChannel]; callers depend only on this
/// contract so corner detection can be mocked in tests without a device.
abstract interface class CornerDetector {
  /// Detects document corners from an image file.
  ///
  /// Returns null if no document rectangle is found. Coordinates are in the
  /// pixel space of the image.
  Future<DocumentCorners?> detectCorners({required String imagePath});

  /// Detects document corners from a raw camera frame (realtime).
  ///
  /// Returns [NormalizedCorners] with 0-1 coordinates, or null if no rectangle
  /// is found, detection is busy, or on error.
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
