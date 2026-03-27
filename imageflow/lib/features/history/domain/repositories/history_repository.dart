import '../../../../core/error/result.dart';
import '../entities/processing_history.dart';

abstract class HistoryRepository {
  Future<Result<List<ProcessingHistory>>> getAll();
  Future<Result<ProcessingHistory>> getById(String id);
  Future<Result<void>> save(ProcessingHistory history);
  Future<Result<void>> delete(String id);
}
