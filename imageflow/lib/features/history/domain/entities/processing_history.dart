import '../../../../core/enums/processing_type.dart';

class ProcessingHistory {
  const ProcessingHistory({
    required this.id,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.type,
    required this.createdAt,
    required this.fileSizeBytes,
    this.thumbnailPath,
    this.pdfPath,
    this.extractedText,
    this.facesDetected = 0,
    this.faceRects = const [],
    this.faceContours = const [],
  });

  final String id;
  final String originalImagePath;
  final String processedImagePath;
  final ProcessingType type;
  final DateTime createdAt;
  final int fileSizeBytes;
  final String? thumbnailPath;
  final String? pdfPath;
  final String? extractedText;
  final int facesDetected;
  final List<({int left, int top, int width, int height})> faceRects;
  final List<List<({int x, int y})>> faceContours;
}
