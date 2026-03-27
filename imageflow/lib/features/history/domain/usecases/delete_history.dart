import '../../../../core/error/result.dart';
import '../repositories/history_repository.dart';

class DeleteHistory {
  const DeleteHistory(this._repository);
  final HistoryRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
