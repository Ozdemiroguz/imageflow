import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../enums/processing_type.dart';

/// Result of content detection — what was found and at which rotation.
class DetectionResult {
  const DetectionResult({
    required this.type,
    this.faces,
    this.recognizedText,
    this.appliedRotation = 0,
  });

  final ProcessingType? type;
  final List<Face>? faces;
  final RecognizedText? recognizedText;

  /// The clockwise rotation (0, 90, 180, 270) that was applied to get a match.
  /// 0 means original orientation worked.
  final int appliedRotation;

  bool get hasFaces => faces != null && faces!.isNotEmpty;
  bool get hasText =>
      recognizedText != null && recognizedText!.text.isNotEmpty;
  bool get hasContent => hasFaces || hasText;
}
