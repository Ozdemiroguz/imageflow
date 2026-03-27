import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/services/file_service.dart';
import 'package:imageflow/features/history/data/models/processing_history_model.dart';
import 'package:imageflow/features/history/data/repositories/history_repository_impl.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<ProcessingHistoryModel> {}

class _MockFileService extends Mock implements FileService {}

class _FakeProcessingHistoryModel extends Fake
    implements ProcessingHistoryModel {}

ProcessingHistory _fakeHistory({
  String id = 'id-1',
  ProcessingType type = ProcessingType.face,
  String? pdfPath,
  String? thumbnailPath,
}) => ProcessingHistory(
  id: id,
  originalImagePath: 'originals/$id.jpg',
  processedImagePath: 'processed/$id.jpg',
  type: type,
  createdAt: DateTime(2024),
  fileSizeBytes: 1024,
  thumbnailPath: thumbnailPath,
  pdfPath: pdfPath,
);

ProcessingHistoryModel _fakeModel({
  String id = 'id-1',
  String? pdfPath,
  String? thumbnailPath,
}) => ProcessingHistoryModel(
  id: id,
  originalImagePath: 'originals/$id.jpg',
  processedImagePath: 'processed/$id.jpg',
  type: ProcessingTypeModel.face,
  createdAt: DateTime(2024),
  fileSizeBytes: 1024,
  pdfPath: pdfPath,
  thumbnailPath: thumbnailPath,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProcessingHistoryModel());
  });

  late _MockBox box;
  late _MockFileService fileService;
  late HistoryRepositoryImpl repo;

  setUp(() {
    box = _MockBox();
    fileService = _MockFileService();
    repo = HistoryRepositoryImpl(box, fileService);

    // Default: resolvePath prepends '/base/'
    when(
      () => fileService.resolvePath(any()),
    ).thenAnswer((inv) => '/base/${inv.positionalArguments.first}');
  });

  group('HistoryRepositoryImpl', () {
    group('getAll', () {
      test('returns Ok with empty list when box is empty', () async {
        when(() => box.values).thenReturn([]);

        final result = await repo.getAll();

        expect(result.isOk, isTrue);
        expect((result as Ok<List<ProcessingHistory>>).value, isEmpty);
      });

      test('returns Ok list sorted newest first', () async {
        final modelOld = ProcessingHistoryModel(
          id: 'old',
          originalImagePath: 'originals/old.jpg',
          processedImagePath: 'processed/old.jpg',
          type: ProcessingTypeModel.face,
          createdAt: DateTime(2023),
          fileSizeBytes: 512,
        );
        final modelNew = ProcessingHistoryModel(
          id: 'new',
          originalImagePath: 'originals/new.jpg',
          processedImagePath: 'processed/new.jpg',
          type: ProcessingTypeModel.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );

        when(() => box.values).thenReturn([modelOld, modelNew]);

        final result = await repo.getAll();

        final items = (result as Ok<List<ProcessingHistory>>).value;
        expect(items.first.id, 'new');
        expect(items.last.id, 'old');
      });

      test('resolves relative paths via FileService', () async {
        final model = _fakeModel(id: 'x');
        when(() => box.values).thenReturn([model]);

        final result = await repo.getAll();

        final item = (result as Ok<List<ProcessingHistory>>).value.first;
        expect(item.originalImagePath, '/base/originals/x.jpg');
        expect(item.processedImagePath, '/base/processed/x.jpg');
      });

      test('resolves thumbnailPath when present', () async {
        final model = _fakeModel(id: 'x', thumbnailPath: 'thumbs/x.jpg');
        when(() => box.values).thenReturn([model]);

        final result = await repo.getAll();

        final item = (result as Ok<List<ProcessingHistory>>).value.first;
        expect(item.thumbnailPath, '/base/thumbs/x.jpg');
      });

      test('leaves thumbnailPath null when absent', () async {
        final model = _fakeModel(id: 'x');
        when(() => box.values).thenReturn([model]);

        final result = await repo.getAll();

        final item = (result as Ok<List<ProcessingHistory>>).value.first;
        expect(item.thumbnailPath, isNull);
      });

      test('resolves pdfPath when present', () async {
        final model = _fakeModel(id: 'x', pdfPath: 'pdfs/x.pdf');
        when(() => box.values).thenReturn([model]);

        final result = await repo.getAll();

        final item = (result as Ok<List<ProcessingHistory>>).value.first;
        expect(item.pdfPath, '/base/pdfs/x.pdf');
      });

      test('returns Error(StorageFailure) when box.values throws', () async {
        when(() => box.values).thenThrow(Exception('hive error'));

        final result = await repo.getAll();

        expect(result.isError, isTrue);
        expect((result as Error<List<ProcessingHistory>>).failure, isA<StorageFailure>());
      });
    });

    group('getById', () {
      test('returns Ok with resolved entity when id exists', () async {
        final model = _fakeModel(id: 'abc');
        when(() => box.get('abc')).thenReturn(model);

        final result = await repo.getById('abc');

        expect(result.isOk, isTrue);
        final item = (result as Ok<ProcessingHistory>).value;
        expect(item.id, 'abc');
        expect(item.originalImagePath, '/base/originals/abc.jpg');
      });

      test('returns Error(StorageFailure) when id not found', () async {
        when(() => box.get('missing')).thenReturn(null);

        final result = await repo.getById('missing');

        expect(result.isError, isTrue);
        expect((result as Error<ProcessingHistory>).failure, isA<StorageFailure>());
      });

      test('returns Error when box.get throws', () async {
        when(() => box.get(any())).thenThrow(Exception('io error'));

        final result = await repo.getById('id');

        expect(result.isError, isTrue);
        expect((result as Error<ProcessingHistory>).failure, isA<StorageFailure>());
      });
    });

    group('save', () {
      test('calls box.put with correct key', () async {
        final history = _fakeHistory(id: 'save-1');
        when(
          () => box.put(any(), any()),
        ).thenAnswer((_) async {});

        await repo.save(history);

        verify(() => box.put('save-1', any())).called(1);
      });

      test('returns Ok<void> on success', () async {
        final history = _fakeHistory(id: 'save-2');
        when(() => box.put(any(), any())).thenAnswer((_) async {});

        final result = await repo.save(history);

        expect(result.isOk, isTrue);
      });

      test('returns Error(StorageFailure) when box.put throws', () async {
        final history = _fakeHistory(id: 'fail');
        when(() => box.put(any(), any())).thenThrow(Exception('disk full'));

        final result = await repo.save(history);

        expect(result.isError, isTrue);
        expect((result as Error<void>).failure, isA<StorageFailure>());
      });
    });

    group('delete', () {
      test('calls box.delete with correct id', () async {
        when(() => box.delete(any())).thenAnswer((_) async {});

        await repo.delete('del-1');

        verify(() => box.delete('del-1')).called(1);
      });

      test('returns Ok<void> on success', () async {
        when(() => box.delete(any())).thenAnswer((_) async {});

        final result = await repo.delete('del-2');

        expect(result.isOk, isTrue);
      });

      test('returns Error(StorageFailure) when box.delete throws', () async {
        when(() => box.delete(any())).thenThrow(Exception('lock error'));

        final result = await repo.delete('del-3');

        expect(result.isError, isTrue);
        expect((result as Error<void>).failure, isA<StorageFailure>());
      });
    });
  });
}
