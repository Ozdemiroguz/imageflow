import '../../../../core/error/result.dart';
import '../entities/processing_history.dart';
import '../repositories/history_repository.dart';

class SaveHistory {
  const SaveHistory(this._repository);
  final HistoryRepository _repository;

  Future<Result<void>> call(ProcessingHistory history) =>
      _repository.save(history);
}
