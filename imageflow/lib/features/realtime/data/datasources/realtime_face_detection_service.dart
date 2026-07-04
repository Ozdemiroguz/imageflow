import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/platform/camera_input_image_factory.dart';

/// Lightweight face detection service for camera stream frames.
class RealtimeFaceDetectionService {
  RealtimeFaceDetectionService({FaceDetector? detector})
    : _detector =
          detector ??
          FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.fast,
              enableContours: false,
              enableLandmarks: false,
              enableClassification: false,
              enableTracking: true,
              // A face must fill at least 15% of the frame's shorter side.
              // The previous 0.06 was low enough that texture/shadow on a blank
              // surface registered as tiny "faces" (the "6 faces on a desk"
              // false positives). 0.15 keeps real, framed faces and drops noise.
              minFaceSize: 0.15,
            ),
          );

  final FaceDetector _detector;

  Future<List<Face>> detect({
    required CameraImage frame,
    required InputImageRotation rotation,
    Uint8List? androidNv21Bytes,
    InputImage? preparedInputImage,
  }) async {
    final input =
        preparedInputImage ??
        buildCameraInputImage(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: androidNv21Bytes,
        );
    if (input == null) return const [];
    return _detector.processImage(input);
  }

  Future<void> close() => _detector.close();
}
