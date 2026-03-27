import '../../../../core/enums/processing_type.dart';

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
  final List<({int left, int top, int width, int height})> faceRects;
  final List<List<({int x, int y})>> faceContours;

  // Document-specific
  final String? extractedText;
  final String? pdfPath;
}
