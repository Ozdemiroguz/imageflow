import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Converts CameraImage (YUV420/NV21) into tightly packed NV21 bytes.
///
/// - If input already has a single plane (likely NV21), returns it as-is.
/// - If input has 3 planes (Y, U, V), reconstructs interleaved VU layout.
Uint8List? cameraImageToNv21(CameraImage frame) {
  if (frame.planes.isEmpty) return null;

  if (frame.planes.length == 1) {
    return frame.planes.first.bytes;
  }

  if (frame.planes.length < 3) return null;

  final width = frame.width;
  final height = frame.height;
  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];

  final out = Uint8List(width * height + (width * height ~/ 2));
  var outIndex = 0;

  for (var row = 0; row < height; row++) {
    final yRowStart = row * yPlane.bytesPerRow;
    final yRowEnd = yRowStart + width;
    if (yRowEnd > yPlane.bytes.length) return null;
    out.setRange(outIndex, outIndex + width, yPlane.bytes, yRowStart);
    outIndex += width;
  }

  final uvWidth = width ~/ 2;
  final uvHeight = height ~/ 2;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;

  for (var row = 0; row < uvHeight; row++) {
    final uRowStart = row * uPlane.bytesPerRow;
    final vRowStart = row * vPlane.bytesPerRow;
    for (var col = 0; col < uvWidth; col++) {
      final uIndex = uRowStart + col * uPixelStride;
      final vIndex = vRowStart + col * vPixelStride;
      if (uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
        return null;
      }
      out[outIndex++] = vPlane.bytes[vIndex];
      out[outIndex++] = uPlane.bytes[uIndex];
    }
  }

  return out;
}
