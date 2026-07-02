import '../services/file_service.dart';
import '../../features/history/domain/entities/processing_history.dart';
import '../../features/processing/domain/entities/processing_result.dart';

/// Maps the pipeline output [ProcessingResult] to the persistence-facing
/// [ProcessingHistory].
///
/// The two entities are deliberately distinct (see their class docs):
/// `ProcessingResult` carries **absolute** paths for immediate UI use, while
/// `ProcessingHistory` carries **relative** paths for storage. This mapper owns
/// that absolute→relative translation, delegating path construction to
/// [FileService] so it stays the single source of truth.
class ProcessingHistoryMapper {
  const ProcessingHistoryMapper({required FileService fileService})
    : _fileService = fileService;

  final FileService _fileService;

  /// For persistence: rewrites absolute paths to relative (storage) paths.
  ProcessingHistory toPersisted(ProcessingResult result) => ProcessingHistory(
    id: result.id,
    originalImagePath: _fileService.relativeOriginalPath(result.id),
    processedImagePath: _fileService.relativeProcessedPath(result.id),
    type: result.type,
    createdAt: result.createdAt,
    fileSizeBytes: result.fileSizeBytes,
    thumbnailPath: _fileService.relativeThumbnailPath(result.id),
    extractedText: result.extractedText,
    facesDetected: result.facesDetected,
    faceRects: result.faceRects,
    faceContours: result.faceContours,
    pdfPath: result.pdfPath != null
        ? _fileService.relativePdfPath(result.id)
        : null,
  );

  /// For navigation/detail: keeps the absolute paths as-is (not for storage).
  ProcessingHistory toDetail(ProcessingResult result) => ProcessingHistory(
    id: result.id,
    originalImagePath: result.originalImagePath,
    processedImagePath: result.processedImagePath,
    type: result.type,
    createdAt: result.createdAt,
    fileSizeBytes: result.fileSizeBytes,
    thumbnailPath: result.thumbnailPath,
    extractedText: result.extractedText,
    facesDetected: result.facesDetected,
    faceRects: result.faceRects,
    faceContours: result.faceContours,
    pdfPath: result.pdfPath,
  );
}
