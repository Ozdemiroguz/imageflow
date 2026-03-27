import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/utils/realtime_input_image_factory.dart';

typedef OcrGateResult = ({bool hasText});

/// OCR gate service for realtime document checks.
///
/// The consumer can use [hasText] to decide whether expensive edge detection
/// should run on the same frame window.
class RealtimeOcrGateService {
  RealtimeOcrGateService({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? TextRecognizer();

  final TextRecognizer _recognizer;

  Future<OcrGateResult> evaluate({
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
    if (input == null) return (hasText: false);

    final recognized = await _recognizer.processImage(input);
    final length = recognized.text.trim().length;
    return (hasText: length > 0);
  }

  Future<void> close() => _recognizer.close();
}
