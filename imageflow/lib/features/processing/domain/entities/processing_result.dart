import '../../../../core/enums/processing_type.dart';
import '../../../../core/models/face_geometry.dart';

class ProcessingResult {
  const ProcessingResult({
    required this.id,
    required this.type,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.thumbnailPath,
    required this.fileSizeBytes,
    required this.createdAt,
    this.facesDetected = 0,
    this.faceRects = const [],
    this.faceContours = const [],
    this.extractedText,
    this.pdfPath,
  });

  final String id;
  final ProcessingType type;
  final String originalImagePath;
  final String processedImagePath;
  final String thumbnailPath;
  final int fileSizeBytes;
  final DateTime createdAt;

  // Face-specific
  final int facesDetected;
  final List<FaceRect> faceRects;
  final List<List<ContourPoint>> faceContours;

  // Document-specific
  final String? extractedText;
  final String? pdfPath;
}
