import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/history/domain/repositories/history_repository.dart';
import 'package:imageflow/features/history/domain/usecases/delete_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryRepository extends Mock implements HistoryRepository {}

void main() {
  late _MockHistoryRepository repository;
  late DeleteHistory useCase;

  setUp(() {
    repository = _MockHistoryRepository();
    useCase = DeleteHistory(repository);
  });

  group('DeleteHistory', () {
    test('delegates to repository.delete with the given id', () async {
      when(() => repository.delete('abc'))
          .thenAnswer((_) async => Result.ok(null));

      await useCase('abc');

      verify(() => repository.delete('abc')).called(1);
    });

    test('returns Ok<void> on successful deletion', () async {
      when(() => repository.delete('abc'))
          .thenAnswer((_) async => Result.ok(null));

      final result = await useCase('abc');

      expect(result.isOk, isTrue);
    });

    test('returns Error when repository returns StorageFailure', () async {
      when(() => repository.delete('missing'))
          .thenAnswer((_) async => Result.error(const StorageFailure()));

      final result = await useCase('missing');

      expect(result.isError, isTrue);
      expect((result as Error<void>).failure, isA<StorageFailure>());
    });

    test('passes the exact id string to repository', () async {
      const id = 'unique-uuid-1234';
      when(() => repository.delete(id))
          .thenAnswer((_) async => Result.ok(null));

      await useCase(id);

      verify(() => repository.delete(id)).called(1);
      verifyNever(() => repository.delete(any()));
    });
  });
}
