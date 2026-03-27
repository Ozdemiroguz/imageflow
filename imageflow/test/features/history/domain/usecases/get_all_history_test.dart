import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/history/domain/repositories/history_repository.dart';
import 'package:imageflow/features/history/domain/usecases/get_all_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockHistoryRepository extends Mock implements HistoryRepository {}

ProcessingHistory _fakeHistory({String id = 'id-1'}) => ProcessingHistory(
      id: id,
      originalImagePath: '/originals/$id.jpg',
      processedImagePath: '/processed/$id.jpg',
      type: ProcessingType.face,
      createdAt: DateTime(2024),
      fileSizeBytes: 512,
    );

void main() {
  late _MockHistoryRepository repository;
  late GetAllHistory useCase;

  setUp(() {
    repository = _MockHistoryRepository();
    useCase = GetAllHistory(repository);
  });

  group('GetAllHistory', () {
    test('delegates to repository.getAll', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => Result.ok([]));

      await useCase();

      verify(() => repository.getAll()).called(1);
    });

    test('returns Ok with empty list when no history exists', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => Result.ok([]));

      final result = await useCase();

      expect(result.isOk, isTrue);
      expect((result as Ok<List<ProcessingHistory>>).value, isEmpty);
    });

    test('returns Ok with all history items', () async {
      final items = [_fakeHistory(id: 'a'), _fakeHistory(id: 'b')];
      when(() => repository.getAll())
          .thenAnswer((_) async => Result.ok(items));

      final result = await useCase();

      expect(result.isOk, isTrue);
      expect((result as Ok<List<ProcessingHistory>>).value, hasLength(2));
    });

    test('returns Error when repository returns StorageFailure', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => Result.error(const StorageFailure()));

      final result = await useCase();

      expect(result.isError, isTrue);
      expect(
        (result as Error<List<ProcessingHistory>>).failure,
        isA<StorageFailure>(),
      );
    });
  });
}
