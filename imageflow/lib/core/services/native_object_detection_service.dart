import 'package:flutter/services.dart';

import '../error/failures.dart';
import '../error/result.dart';
import '../models/detected_object_info.dart';
import '../platform/object_detector.dart';
import '../utils/log.dart';

/// Native object detection via Method Channel.
///
/// iOS: Core ML (Apple gallery COCO detector) through VNCoreMLRequest.
/// Android: EfficientDet-Lite0 through MediaPipe Tasks ObjectDetector.
/// Both return COCO-labeled boxes in normalized 0-1 coordinates.
class NativeObjectDetectionService implements ObjectDetector {
  NativeObjectDetectionService({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.oguzhan.imageflow/object_detection');

  final MethodChannel _channel;

  static const _tag = 'NativeObjectDetection';

  @override
  Future<Result<List<DetectedObjectInfo>>> detectObjects({
    required String imagePath,
  }) async {
    try {
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'detectObjects',
        {'imagePath': imagePath},
      );

      final objects = _mapObjects(result);
      Log.debug('Detected ${objects.length} object(s) in file.', tag: _tag);
      return Result.ok(objects);
    } on PlatformException catch (e, st) {
      Log.error(
        'Object detection platform error: ${e.message}',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return Result.error(
        NativeChannelFailure('Object detection failed: ${e.message}'),
      );
    } on MissingPluginException catch (e, st) {
      Log.warning(
        'Object detection not implemented on this platform.',
        tag: _tag,
      );
      Log.error('MissingPlugin', error: e, stackTrace: st, tag: _tag);
      return Result.error(
        const NativeChannelFailure(
          'Object detection is not available on this platform.',
        ),
      );
    } catch (e, st) {
      Log.error(
        'Unexpected error in object detection: $e',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return Result.error(NativeChannelFailure('Object detection failed: $e'));
    }
  }

  /// Detect objects from a raw camera frame (realtime).
  ///
  /// **iOS (BGRA)**: pass [bytes] as a single BGRA plane with [bytesPerRow].
  /// **Android (YUV420)**: pass [yBytes]/[uBytes]/[vBytes] with strides.
  ///
  /// Returns an empty list if none / busy / on error (drop-frame hot-path).
  @override
  Future<List<DetectedObjectInfo>> detectObjectsFromFrame({
    required int width,
    required int height,
    required int rotation,
    Uint8List? bytes,
    int bytesPerRow = 0,
    Uint8List? yBytes,
    Uint8List? uBytes,
    Uint8List? vBytes,
    int yRowStride = 0,
    int uvRowStride = 0,
    int uvPixelStride = 1,
    String format = 'bgra',
  }) async {
    try {
      final result = await _channel
          .invokeListMethod<Map<Object?, Object?>>('detectObjectsFromFrame', {
            'width': width,
            'height': height,
            'rotation': rotation,
            'format': format,
            'bytes': ?bytes,
            if (bytesPerRow > 0) 'bytesPerRow': bytesPerRow,
            'yBytes': ?yBytes,
            'uBytes': ?uBytes,
            'vBytes': ?vBytes,
            if (yRowStride > 0) 'yRowStride': yRowStride,
            if (uvRowStride > 0) 'uvRowStride': uvRowStride,
            'uvPixelStride': uvPixelStride,
          });

      return _mapObjects(result);
    } catch (e) {
      Log.error('Frame object detection error: $e', error: e, tag: _tag);
      return const [];
    }
  }

  List<DetectedObjectInfo> _mapObjects(List<Map<Object?, Object?>>? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .map((item) {
          final trackingId = item['trackingId'];
          return DetectedObjectInfo(
            label: (item['label'] as String?) ?? 'object',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
            rect: (
              left: (item['left'] as num).toDouble(),
              top: (item['top'] as num).toDouble(),
              right: (item['right'] as num).toDouble(),
              bottom: (item['bottom'] as num).toDouble(),
            ),
            trackingId: trackingId is num ? trackingId.toInt() : null,
          );
        })
        .toList(growable: false);
  }
}
