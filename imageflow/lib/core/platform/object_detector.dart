import 'dart:typed_data';

import '../error/result.dart';
import '../models/detected_object_info.dart';

/// Detects objects via a native platform implementation (Core ML on iOS,
/// EfficientDet-Lite0 via MediaPipe on Android).
///
/// Implementations own the [MethodChannel]; callers depend only on this
/// contract so object detection can be mocked in tests without a device. The
/// two entry points mirror [CornerDetector]'s dual contract.
abstract interface class ObjectDetector {
  /// Detects objects in an image file. Returns `Ok([])` when nothing is found
  /// (a valid outcome) and `Error(failure)` on a real detection failure — so
  /// callers can tell "no objects" apart from "detection broke".
  Future<Result<List<DetectedObjectInfo>>> detectObjects({
    required String imagePath,
  });

  /// Detects objects in a raw camera frame (realtime). Returns the objects in
  /// normalized 0-1 coordinates, or an empty list if none / busy / on error.
  ///
  /// **Deliberately returns a list (never throws / never a Result) on error**:
  /// this is a per-frame hot path where the correct behavior is to drop the
  /// frame and continue — wrapping every frame in a Result would add allocation
  /// against the frame budget for no benefit (same rationale as
  /// [CornerDetector.detectCornersFromFrame]).
  Future<List<DetectedObjectInfo>> detectObjectsFromFrame({
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
