import '../../../../core/enums/processing_type.dart';
import '../../../../core/models/face_geometry.dart';

/// A persisted record of a completed processing run, owned by the `history`
/// feature.
///
/// Deliberately distinct from `ProcessingResult` (the `processing` feature's
/// pipeline output, which it shares most fields with): this entity stores
/// **relative** paths so records survive app-container UUID changes, and its
/// `thumbnailPath` is nullable because legacy records may lack one. The
/// absolute→relative translation lives in `ProcessingHistoryMapper`.
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
  final List<FaceRect> faceRects;
  final List<List<ContourPoint>> faceContours;
}
