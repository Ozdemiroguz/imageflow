import '../../../core/services/file_service.dart';
import '../../history/domain/entities/processing_history.dart';
import '../../processing/domain/entities/processing_result.dart';

class BatchHistoryMapper {
  const BatchHistoryMapper({required FileService fileService})
    : _fileService = fileService;

  final FileService _fileService;

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
