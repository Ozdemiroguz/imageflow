import 'dart:typed_data';

import '../error/result.dart';
import '../models/document_corners.dart';
import '../models/normalized_corners.dart';

/// Detects document corners via a native platform implementation.
///
/// Implementations own the [MethodChannel]; callers depend only on this
/// contract so corner detection can be mocked in tests without a device.
abstract interface class CornerDetector {
  /// Detects document corners from an image file.
  ///
  /// Returns `Ok(null)` when no rectangle is found (a valid outcome) and
  /// `Error(failure)` on a real detection failure — so callers can tell "no
  /// document" apart from "detection broke". Coordinates are in pixel space.
  Future<Result<DocumentCorners?>> detectCorners({required String imagePath});

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
