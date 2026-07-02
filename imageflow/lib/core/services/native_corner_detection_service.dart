import 'package:flutter/services.dart';

import '../error/failures.dart';
import '../error/result.dart';
import '../models/document_corners.dart';
import '../models/normalized_corners.dart';
import '../platform/corner_detector.dart';
import '../utils/log.dart';

/// Native document corner detection via Method Channel.
///
/// iOS: Vision Framework (VNDetectRectanglesRequest)
/// Android: native corner detection handler (frame/file based)
class NativeCornerDetectionService implements CornerDetector {
  NativeCornerDetectionService({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.oguzhan.imageflow/corner_detection');

  final MethodChannel _channel;

  static const _tag = 'NativeCornerDetection';

  /// Detect document corners from an image file.
  ///
  /// Returns `Ok(null)` when no rectangle is found (valid) and `Error` on a
  /// real detection failure. Coordinates are in pixel space of the image.
  @override
  Future<Result<DocumentCorners?>> detectCorners({
    required String imagePath,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'detectCorners',
        {'imagePath': imagePath},
      );

      if (result == null) {
        Log.info('No document corners detected.', tag: _tag);
        return Result.ok(null);
      }

      final corners = DocumentCorners(
        topLeft: (
          x: (result['topLeftX'] as num).toDouble(),
          y: (result['topLeftY'] as num).toDouble(),
        ),
        topRight: (
          x: (result['topRightX'] as num).toDouble(),
          y: (result['topRightY'] as num).toDouble(),
        ),
        bottomRight: (
          x: (result['bottomRightX'] as num).toDouble(),
          y: (result['bottomRightY'] as num).toDouble(),
        ),
        bottomLeft: (
          x: (result['bottomLeftX'] as num).toDouble(),
          y: (result['bottomLeftY'] as num).toDouble(),
        ),
      );

      Log.debug(
        'Corners detected — '
        'TL:(${corners.topLeft.x.round()},${corners.topLeft.y.round()}) '
        'TR:(${corners.topRight.x.round()},${corners.topRight.y.round()}) '
        'BR:(${corners.bottomRight.x.round()},${corners.bottomRight.y.round()}) '
        'BL:(${corners.bottomLeft.x.round()},${corners.bottomLeft.y.round()})',
        tag: _tag,
      );

      return Result.ok(corners);
    } on PlatformException catch (e, st) {
      Log.error(
        'Corner detection platform error: ${e.message}',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return Result.error(
        NativeChannelFailure('Corner detection failed: ${e.message}'),
      );
    } on MissingPluginException catch (e, st) {
      Log.warning(
        'Corner detection not implemented on this platform.',
        tag: _tag,
      );
      Log.error('MissingPlugin', error: e, stackTrace: st, tag: _tag);
      return Result.error(
        const NativeChannelFailure(
          'Corner detection is not available on this platform.',
        ),
      );
    } catch (e, st) {
      Log.error(
        'Unexpected error in corner detection: $e',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return Result.error(NativeChannelFailure('Corner detection failed: $e'));
    }
  }

  /// Detect document corners from a raw camera frame (realtime).
  ///
  /// **iOS (BGRA)**: Pass [bytes] as single BGRA plane with [bytesPerRow].
  /// **Android (YUV420)**: Pass individual [yBytes], [uBytes], [vBytes] with
  /// strides so native side can reconstruct NV21 correctly per-device.
  ///
  /// Returns [NormalizedCorners] with 0-1 coordinates (caller maps to preview).
  /// Returns null if no rectangle found, detection is busy, or on error.
  @override
  Future<NormalizedCorners?> detectCornersFromFrame({
    required int width,
    required int height,
    required int rotation,
    // iOS (BGRA single plane)
    Uint8List? bytes,
    int bytesPerRow = 0,
    // Android (YUV420 individual planes + strides)
    Uint8List? yBytes,
    Uint8List? uBytes,
    Uint8List? vBytes,
    int yRowStride = 0,
    int uvRowStride = 0,
    int uvPixelStride = 1,
    String format = 'bgra',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'detectCornersFromFrame',
        {
          'width': width,
          'height': height,
          'rotation': rotation,
          'format': format,
          // iOS BGRA
          'bytes': ?bytes,
          if (bytesPerRow > 0) 'bytesPerRow': bytesPerRow,
          // Android YUV420 planes
          'yBytes': ?yBytes,
          'uBytes': ?uBytes,
          'vBytes': ?vBytes,
          if (yRowStride > 0) 'yRowStride': yRowStride,
          if (uvRowStride > 0) 'uvRowStride': uvRowStride,
          'uvPixelStride': uvPixelStride,
        },
      );

      if (result == null) return null;

      return NormalizedCorners(
        topLeft: (
          x: (result['topLeftX'] as num).toDouble(),
          y: (result['topLeftY'] as num).toDouble(),
        ),
        topRight: (
          x: (result['topRightX'] as num).toDouble(),
          y: (result['topRightY'] as num).toDouble(),
        ),
        bottomRight: (
          x: (result['bottomRightX'] as num).toDouble(),
          y: (result['bottomRightY'] as num).toDouble(),
        ),
        bottomLeft: (
          x: (result['bottomLeftX'] as num).toDouble(),
          y: (result['bottomLeftY'] as num).toDouble(),
        ),
      );
    } catch (e) {
      Log.error('Frame corner detection error: $e', error: e, tag: _tag);
      return null;
    }
  }
}
