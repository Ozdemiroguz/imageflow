import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'android_nv21.dart';

/// Builds a realtime ML Kit [InputImage] from camera stream frame.
///
/// Android expects NV21 bytes, iOS expects BGRA8888.
InputImage? buildRealtimeInputImage({
  required CameraImage frame,
  required InputImageRotation rotation,
  Uint8List? androidNv21Bytes,
}) {
  if (Platform.isIOS) {
    final rawFormat = frame.format.raw;
    final format = rawFormat is int
        ? InputImageFormatValue.fromRawValue(rawFormat)
        : null;
    if (format != InputImageFormat.bgra8888 || frame.planes.isEmpty) {
      return null;
    }
    final plane = frame.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  if (Platform.isAndroid) {
    final bytes = androidNv21Bytes ?? cameraImageToNv21(frame);
    if (bytes == null) return null;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.width,
      ),
    );
  }

  return null;
}
