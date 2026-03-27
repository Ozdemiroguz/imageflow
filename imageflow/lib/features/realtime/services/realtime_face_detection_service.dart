import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/utils/realtime_input_image_factory.dart';

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
              minFaceSize: 0.06,
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
        buildRealtimeInputImage(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: androidNv21Bytes,
        );
    if (input == null) return const [];
    return _detector.processImage(input);
  }

  Future<void> close() => _detector.close();
}
