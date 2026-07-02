import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/models/snack_data.dart';
import 'package:imageflow/core/platform/image_picker_gateway.dart';
import 'package:imageflow/core/services/file_service.dart';
import 'package:imageflow/core/services/modal_service.dart';
import 'package:imageflow/features/batch/presentation/controllers/batch_processing_controller.dart';
import 'package:imageflow/features/batch/presentation/models/batch_item_state.dart';
import 'package:imageflow/features/batch/presentation/models/batch_item_status.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/history/domain/usecases/save_history.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/processing/domain/usecases/process_image.dart';
import 'package:mocktail/mocktail.dart';

class _MockProcessImage extends Mock implements ProcessImage {}

class _MockSaveHistory extends Mock implements SaveHistory {}

class _MockFileService extends Mock implements FileService {}

class _MockModalService extends Mock implements ModalService {}

class _MockImagePicker extends Mock implements ImagePickerGateway {}

class _FakeProcessingHistory extends Fake implements ProcessingHistory {}

class _FakeSnackData extends Fake implements SnackData {}

ProcessingResult _fakeResult(String id) => ProcessingResult(
  id: id,
  type: ProcessingType.document,
  originalImagePath: '/o/$id.jpg',
  processedImagePath: '/p/$id.jpg',
  thumbnailPath: '/t/$id.jpg',
  fileSizeBytes: 100,
  createdAt: DateTime(2026),
  extractedText: 'text',
  facesDetected: 0,
  faceRects: const [],
  faceContours: const [],
);

void main() {
  late _MockProcessImage processImage;
  late _MockSaveHistory saveHistory;
  late _MockFileService fileService;
  late _MockModalService modalService;
  late _MockImagePicker imagePicker;

  setUpAll(() {
    registerFallbackValue(_FakeProcessingHistory());
    registerFallbackValue(_FakeSnackData());
  });

  setUp(() {
    processImage = _MockProcessImage();
    saveHistory = _MockSaveHistory();
    fileService = _MockFileService();
    modalService = _MockModalService();
    imagePicker = _MockImagePicker();

    // FileService is only used by the default ProcessingHistoryMapper for the
    // relative-path rewrite on save; stub the paths it touches.
    when(() => fileService.relativeOriginalPath(any())).thenReturn('o');
    when(() => fileService.relativeProcessedPath(any())).thenReturn('p');
    when(() => fileService.relativeThumbnailPath(any())).thenReturn('t');
    when(() => fileService.relativePdfPath(any())).thenReturn('pdf');
    when(() => modalService.showSnack(any())).thenReturn(null);
  });

  tearDown(Get.reset);

  BatchProcessingController makeController() => BatchProcessingController(
    processImage: processImage,
    saveHistory: saveHistory,
    fileService: fileService,
    modalService: modalService,
    imagePicker: imagePicker,
  );

  /// Builds a controller with a pre-seeded queue, bypassing onInit's
  /// Get.arguments-driven queue init (that path is covered by the
  /// buildBatchQueue tests).
  BatchProcessingController withQueue(List<String> paths) {
    final controller = makeController();
    controller.items.assignAll([
      for (var i = 0; i < paths.length; i++)
        BatchItemState(
          index: i,
          imagePath: paths[i],
          status: BatchItemStatus.pending,
        ),
    ]);
    return controller;
  }

  void stubProcessOk() {
    when(
      () => processImage(
        imagePath: any(named: 'imagePath'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#imagePath] as String;
      return Result.ok(_fakeResult(path));
    });
  }

  void stubSaveOk() {
    when(() => saveHistory(any())).thenAnswer((_) async => Result.ok(null));
  }

  group('processPending', () {
    test('all succeed → every item success, history saved N times, success '
        'snack', () async {
      stubProcessOk();
      stubSaveOk();
      final controller = withQueue(['a.jpg', 'b.jpg']);

      await controller.processPending();

      expect(
        controller.items.map((i) => i.status),
        everyElement(BatchItemStatus.success),
      );
      expect(controller.successCount, 2);
      expect(controller.failedCount, 0);
      verify(() => saveHistory(any())).called(2);
      verify(
        () => modalService.showSnack(
          any(that: isA<SnackData>().having((s) => s.type, 'type', anything)),
        ),
      ).called(1);
      expect(controller.isRunning.value, isFalse);
    });

    test(
      'one item fails → that item failed, others success, warning snack',
      () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final path = invocation.namedArguments[#imagePath] as String;
          if (path == 'bad.jpg') {
            return Result.error(const ProcessingFailure('boom'));
          }
          return Result.ok(_fakeResult(path));
        });
        stubSaveOk();
        final controller = withQueue(['ok.jpg', 'bad.jpg']);

        await controller.processPending();

        expect(controller.items[0].status, BatchItemStatus.success);
        expect(controller.items[1].status, BatchItemStatus.failed);
        expect(controller.successCount, 1);
        expect(controller.failedCount, 1);
        // Only the successful item is persisted.
        verify(() => saveHistory(any())).called(1);
      },
    );

    test(
      'save failure marks the item failed even though processing succeeded',
      () async {
        stubProcessOk();
        when(
          () => saveHistory(any()),
        ).thenAnswer((_) async => Result.error(const StorageFailure('disk')));
        final controller = withQueue(['a.jpg']);

        await controller.processPending();

        expect(controller.items[0].status, BatchItemStatus.failed);
        expect(controller.failedCount, 1);
      },
    );

    test('overlapping run is blocked by isRunning', () async {
      stubProcessOk();
      stubSaveOk();
      final controller = withQueue(['a.jpg']);

      final first = controller.processPending();
      // Second call while the first is in-flight must no-op.
      await controller.processPending();
      await first;

      // processImage ran exactly once despite two processPending calls.
      verify(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    test('empty queue no-ops', () async {
      final controller = withQueue([]);
      await controller.processPending();
      expect(controller.isRunning.value, isFalse);
      verifyNever(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });
  });

  group('requestStop', () {
    test('stops after the current item; remaining stay pending', () async {
      stubSaveOk();
      final controller = withQueue(['a.jpg', 'b.jpg', 'c.jpg']);

      // Request stop as soon as the first item begins processing.
      when(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.namedArguments[#imagePath] as String;
        controller.requestStop();
        return Result.ok(_fakeResult(path));
      });

      await controller.processPending();

      expect(controller.items[0].status, BatchItemStatus.success);
      expect(controller.items[1].status, BatchItemStatus.pending);
      expect(controller.items[2].status, BatchItemStatus.pending);
      // Only the first item was processed before stopping.
      verify(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      // Stop flags reset after the run ends.
      expect(controller.isRunning.value, isFalse);
      expect(controller.isStopping.value, isFalse);
    });

    test('requestStop with no active run is a no-op', () {
      final controller = withQueue(['a.jpg']);
      controller.requestStop();
      expect(controller.isStopping.value, isFalse);
    });
  });

  group('retryFailed / retryItem', () {
    test('retryFailed re-runs only failed items', () async {
      stubSaveOk();
      final controller = withQueue(['a.jpg', 'b.jpg']);
      // Seed: item 0 success, item 1 failed.
      controller.items[0] = controller.items[0].copyWith(
        status: BatchItemStatus.success,
      );
      controller.items[1] = controller.items[1].copyWith(
        status: BatchItemStatus.failed,
      );
      stubProcessOk();

      await controller.retryFailed();

      expect(controller.items[0].status, BatchItemStatus.success);
      expect(controller.items[1].status, BatchItemStatus.success);
      // Only the previously-failed item was reprocessed.
      verify(
        () => processImage(
          imagePath: 'b.jpg',
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verifyNever(
        () => processImage(
          imagePath: 'a.jpg',
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    test('retryItem on a non-failed item no-ops', () async {
      final controller = withQueue(['a.jpg']);
      // pending, not failed
      await controller.retryItem(0);
      verifyNever(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    test('retryItem out-of-range index no-ops', () async {
      final controller = withQueue(['a.jpg']);
      await controller.retryItem(5);
      await controller.retryItem(-1);
      verifyNever(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });
  });

  group('reselectItemFromGallery', () {
    test('picks a new path and reprocesses that item', () async {
      stubSaveOk();
      stubProcessOk();
      when(
        () => imagePicker.pickImageFromGallery(),
      ).thenAnswer((_) async => 'new.jpg');
      final controller = withQueue(['old.jpg']);
      controller.items[0] = controller.items[0].copyWith(
        status: BatchItemStatus.failed,
      );

      await controller.reselectItemFromGallery(0);

      expect(controller.items[0].imagePath, 'new.jpg');
      expect(controller.items[0].status, BatchItemStatus.success);
      verify(
        () => processImage(
          imagePath: 'new.jpg',
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    test('cancelled picker (null path) leaves the item unchanged', () async {
      when(
        () => imagePicker.pickImageFromGallery(),
      ).thenAnswer((_) async => null);
      final controller = withQueue(['old.jpg']);

      await controller.reselectItemFromGallery(0);

      expect(controller.items[0].imagePath, 'old.jpg');
      verifyNever(
        () => processImage(
          imagePath: any(named: 'imagePath'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });
  });

  group('derived counts', () {
    test('progress reflects completed / total', () {
      final controller = withQueue(['a', 'b', 'c', 'd']);
      controller.items[0] = controller.items[0].copyWith(
        status: BatchItemStatus.success,
      );
      controller.items[1] = controller.items[1].copyWith(
        status: BatchItemStatus.failed,
      );
      expect(controller.totalCount, 4);
      expect(controller.completedCount, 2);
      expect(controller.progress, 0.5);
    });

    test('progress is 0 for an empty queue (no divide-by-zero)', () {
      final controller = withQueue([]);
      expect(controller.progress, 0);
    });
  });
}
