import '../../../../core/enums/processing_type.dart';
import '../../../../core/models/face_geometry.dart';

/// The immediate output of the processing pipeline.
///
/// Deliberately distinct from `ProcessingHistory` (which it shares most fields
/// with): a [ProcessingResult] carries **absolute** file paths for immediate UI
/// rendering and is owned by the `processing` feature, whereas
/// `ProcessingHistory` carries **relative** paths for persistence and is owned
/// by the `history` feature. Keeping them separate preserves the feature
/// boundary; `ProcessingHistoryMapper` performs the absolute→relative
/// translation between them.
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
