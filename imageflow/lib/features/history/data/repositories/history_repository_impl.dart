import 'package:hive_ce/hive.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/file_service.dart';
import '../../domain/entities/processing_history.dart';
import '../../domain/repositories/history_repository.dart';
import '../models/processing_history_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl(this._box, this._fileService);

  final Box<ProcessingHistoryModel> _box;
  final FileService _fileService;

  @override
  Future<Result<List<ProcessingHistory>>> getAll() => Result.guard(() async {
    final models = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return models.map((m) => _resolve(m.toEntity())).toList();
  }, onError: (e) => StorageFailure('Failed to load history: $e'));

  @override
  Future<Result<ProcessingHistory>> getById(String id) =>
      Result.guard(() async {
        final model = _box.get(id);
        if (model == null) throw const StorageFailure('History item not found');
        return _resolve(model.toEntity());
      }, onError: (e) => StorageFailure('Failed to get history: $e'));

  /// Resolves stored (relative) paths to absolute paths for UI consumption.
  ProcessingHistory _resolve(ProcessingHistory h) => ProcessingHistory(
    id: h.id,
    originalImagePath: _fileService.resolvePath(h.originalImagePath),
    processedImagePath: _fileService.resolvePath(h.processedImagePath),
    type: h.type,
    createdAt: h.createdAt,
    fileSizeBytes: h.fileSizeBytes,
    thumbnailPath: h.thumbnailPath != null
        ? _fileService.resolvePath(h.thumbnailPath!)
        : null,
    pdfPath: h.pdfPath != null ? _fileService.resolvePath(h.pdfPath!) : null,
    extractedText: h.extractedText,
    facesDetected: h.facesDetected,
    faceRects: h.faceRects,
    faceContours: h.faceContours,
  );

  @override
  Future<Result<void>> save(ProcessingHistory history) =>
      Result.guard(() async {
        final model = ProcessingHistoryModel.fromEntity(history);
        await _box.put(history.id, model);
      }, onError: (e) => StorageFailure('Failed to save history: $e'));

  @override
  Future<Result<void>> delete(String id) => Result.guard(
    () async => _box.delete(id),
    onError: (e) => StorageFailure('Failed to delete history: $e'),
  );
}
