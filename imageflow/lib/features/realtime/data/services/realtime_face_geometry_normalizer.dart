import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class RealtimeFaceGeometryNormalizer {
  const RealtimeFaceGeometryNormalizer({
    required bool frameImageUsesNativeRotation,
  }) : _frameImageUsesNativeRotation = frameImageUsesNativeRotation;

  final bool _frameImageUsesNativeRotation;

  int selectPrimaryFaceIndex(List<Rect> faces) {
    if (faces.length <= 1) return 0;

    var primaryIndex = 0;
    var bestArea = faces.first.width * faces.first.height;
    for (var i = 1; i < faces.length; i++) {
      final area = faces[i].width * faces[i].height;
      if (area > bestArea) {
        bestArea = area;
        primaryIndex = i;
      }
    }
    return primaryIndex;
  }

  Rect? normalizeFaceRect(
    Rect rect,
    CameraImage frame, {
    required int nativeRotationDegrees,
    required bool needsMirrorCompensation,
  }) {
    final width = _orientedFrameWidth(frame, nativeRotationDegrees);
    final height = _orientedFrameHeight(frame, nativeRotationDegrees);
    if (width <= 0 || height <= 0) return null;

    var left = (rect.left / width).clamp(0.0, 1.0);
    final top = (rect.top / height).clamp(0.0, 1.0);
    var right = (rect.right / width).clamp(0.0, 1.0);
    final bottom = (rect.bottom / height).clamp(0.0, 1.0);

    if (needsMirrorCompensation) {
      final mirroredLeft = 1.0 - right;
      final mirroredRight = 1.0 - left;
      left = mirroredLeft.clamp(0.0, 1.0);
      right = mirroredRight.clamp(0.0, 1.0);
    }

    final normalizedWidth = right - left;
    final normalizedHeight = bottom - top;
    if (normalizedWidth <= 0 || normalizedHeight <= 0) return null;

    return Rect.fromLTWH(left, top, normalizedWidth, normalizedHeight);
  }

  List<Offset> normalizeFaceContour(
    Face face,
    CameraImage frame, {
    required int nativeRotationDegrees,
    required bool needsMirrorCompensation,
  }) {
    final contour = face.contours[FaceContourType.face]?.points;
    if (contour == null || contour.length < 3) return const [];

    final width = _orientedFrameWidth(frame, nativeRotationDegrees);
    final height = _orientedFrameHeight(frame, nativeRotationDegrees);
    if (width <= 0 || height <= 0) return const [];

    return contour
        .map((point) {
          var dx = (point.x / width).clamp(0.0, 1.0);
          final dy = (point.y / height).clamp(0.0, 1.0);
          if (needsMirrorCompensation) {
            dx = (1.0 - dx).clamp(0.0, 1.0);
          }
          return Offset(dx, dy);
        })
        .toList(growable: false);
  }

  double _orientedFrameWidth(CameraImage frame, int nativeRotationDegrees) {
    if (!_frameImageUsesNativeRotation) return frame.width.toDouble();
    return switch (nativeRotationDegrees) {
      90 || 270 => frame.height.toDouble(),
      _ => frame.width.toDouble(),
    };
  }

  double _orientedFrameHeight(CameraImage frame, int nativeRotationDegrees) {
    if (!_frameImageUsesNativeRotation) return frame.height.toDouble();
    return switch (nativeRotationDegrees) {
      90 || 270 => frame.width.toDouble(),
      _ => frame.height.toDouble(),
    };
  }
}
