import '../../../../core/error/result.dart';
import '../entities/processing_history.dart';
import '../repositories/history_repository.dart';

class GetAllHistory {
  const GetAllHistory(this._repository);
  final HistoryRepository _repository;

  Future<Result<List<ProcessingHistory>>> call() => _repository.getAll();
}
