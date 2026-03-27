import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/history/domain/repositories/history_repository.dart';
import 'package:imageflow/features/history/domain/usecases/save_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryRepository extends Mock implements HistoryRepository {}

ProcessingHistory _fakeHistory() => ProcessingHistory(
      id: 'save-test-id',
      originalImagePath: '/originals/save-test.jpg',
      processedImagePath: '/processed/save-test.jpg',
      type: ProcessingType.document,
      createdAt: DateTime(2024),
      fileSizeBytes: 2048,
    );

void main() {
  late _MockHistoryRepository repository;
  late SaveHistory useCase;

  setUp(() {
    repository = _MockHistoryRepository();
    useCase = SaveHistory(repository);
    registerFallbackValue(_fakeHistory());
  });

  group('SaveHistory', () {
    test('delegates to repository.save with the given history', () async {
      final history = _fakeHistory();
      when(() => repository.save(any()))
          .thenAnswer((_) async => Result.ok(null));

      await useCase(history);

      verify(() => repository.save(history)).called(1);
    });

    test('returns Ok<void> on successful save', () async {
      when(() => repository.save(any()))
          .thenAnswer((_) async => Result.ok(null));

      final result = await useCase(_fakeHistory());

      expect(result.isOk, isTrue);
    });

    test('returns Error when repository returns StorageFailure', () async {
      when(() => repository.save(any()))
          .thenAnswer((_) async => Result.error(const StorageFailure()));

      final result = await useCase(_fakeHistory());

      expect(result.isError, isTrue);
      expect((result as Error<void>).failure, isA<StorageFailure>());
    });

    test('passes the exact history object to repository', () async {
      final history = _fakeHistory();
      when(() => repository.save(history))
          .thenAnswer((_) async => Result.ok(null));

      await useCase(history);

      verify(() => repository.save(history)).called(1);
    });
  });
}
