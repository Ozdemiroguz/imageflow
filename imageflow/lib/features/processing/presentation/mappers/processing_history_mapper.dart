import '../../../../core/constants/storage_constants.dart';
import '../../../history/domain/entities/processing_history.dart';
import '../../domain/entities/processing_result.dart';

class ProcessingHistoryMapper {
  const ProcessingHistoryMapper();

  ProcessingHistory toHistory(ProcessingResult result) => ProcessingHistory(
    id: result.id,
    originalImagePath: '${StorageConstants.originalsDir}/${result.id}.jpg',
    processedImagePath: '${StorageConstants.processedDir}/${result.id}.jpg',
    type: result.type,
    createdAt: result.createdAt,
    fileSizeBytes: result.fileSizeBytes,
    thumbnailPath: '${StorageConstants.thumbnailsDir}/${result.id}_thumb.jpg',
    extractedText: result.extractedText,
    facesDetected: result.facesDetected,
    faceRects: result.faceRects,
    faceContours: result.faceContours,
    pdfPath: result.pdfPath != null
        ? '${StorageConstants.pdfsDir}/${result.id}.pdf'
        : null,
  );
}
