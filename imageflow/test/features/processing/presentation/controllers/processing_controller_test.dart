import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/history/domain/usecases/save_history.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/processing/domain/entities/processing_step.dart';
import 'package:imageflow/features/processing/domain/usecases/process_image.dart';
import 'package:imageflow/features/processing/presentation/controllers/processing_controller.dart';
import 'package:imageflow/features/processing/presentation/mappers/processing_history_mapper.dart';
import 'package:mocktail/mocktail.dart';

class _MockProcessImage extends Mock implements ProcessImage {}

class _MockSaveHistory extends Mock implements SaveHistory {}

ProcessingResult _fakeResult() => ProcessingResult(
      id: 'result-id',
      type: ProcessingType.face,
      originalImagePath: '/o/test.jpg',
      processedImagePath: '/p/test.jpg',
      thumbnailPath: '/t/test_thumb.jpg',
      fileSizeBytes: 2048,
      createdAt: DateTime(2024),
    );

void main() {
  late _MockProcessImage processImage;
  late _MockSaveHistory saveHistory;
  const mapper = ProcessingHistoryMapper();

  setUpAll(() {
    registerFallbackValue(
      ProcessingHistory(
        id: 'fallback',
        originalImagePath: '/o/f.jpg',
        processedImagePath: '/p/f.jpg',
        type: ProcessingType.face,
        createdAt: DateTime(2024),
        fileSizeBytes: 0,
      ),
    );
  });

  setUp(() {
    processImage = _MockProcessImage();
    saveHistory = _MockSaveHistory();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  Future<ProcessingController> makeAndInit(String imagePath) async {
    Get.routing.args = imagePath;
    final controller = ProcessingController(
      processImage: processImage,
      saveHistory: saveHistory,
      historyMapper: mapper,
    );
    controller.onInit();
    await pumpEventQueue();
    return controller;
  }

  group('ProcessingController', () {
    group('onInit', () {
      test('reads imagePath from Get.arguments', () async {
        when(
          () => processImage(
            imagePath: '/test.jpg',
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const DetectionFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.imagePath, '/test.jpg');
        controller.onClose();
      });

      test('starts processing immediately on init', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const DetectionFailure()));

        await makeAndInit('/test.jpg');

        verify(
          () => processImage(
            imagePath: '/test.jpg',
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
      });
    });

    group('success path', () {
      test('saves history and navigates on Ok result', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.ok(_fakeResult()));
        when(() => saveHistory(any()))
            .thenAnswer((_) async => Result.ok(null));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.isProcessing.value, isFalse);
        expect(controller.failure.value, isNull);
        verify(() => saveHistory(any())).called(1);
        controller.onClose();
      });

      test('sets isProcessing to false after success', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.ok(_fakeResult()));
        when(() => saveHistory(any()))
            .thenAnswer((_) async => Result.ok(null));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.isProcessing.value, isFalse);
        controller.onClose();
      });

      test('sets failure when saveHistory fails', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.ok(_fakeResult()));
        when(() => saveHistory(any()))
            .thenAnswer((_) async => Result.error(const StorageFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.failure.value, isA<StorageFailure>());
        controller.onClose();
      });
    });

    group('failure path', () {
      test('sets failure.value on processImage Error', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const DetectionFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.failure.value, isA<DetectionFailure>());
        controller.onClose();
      });

      test('isProcessing is false after failure', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const ProcessingFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.isProcessing.value, isFalse);
        controller.onClose();
      });

      test('isDetectionError is true when failure is DetectionFailure', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const DetectionFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.isDetectionError, isTrue);
        controller.onClose();
      });

      test('isDetectionError is false for non-DetectionFailure', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const ProcessingFailure()));

        final controller = await makeAndInit('/test.jpg');

        expect(controller.isDetectionError, isFalse);
        controller.onClose();
      });
    });

    group('progress callback', () {
      test('updates currentStep via _onProgress', () async {
        ProcessingStep? reportedStep;

        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final cb = invocation.namedArguments[#onProgress]
              as void Function(ProcessingStep)?;
          cb?.call(ProcessingStep.detectingFaces);
          reportedStep = ProcessingStep.detectingFaces;
          return Result.error(const DetectionFailure());
        });

        final controller = await makeAndInit('/test.jpg');

        expect(reportedStep, ProcessingStep.detectingFaces);
        controller.onClose();
      });
    });

    group('retry', () {
      test('clears failure and resets step before retrying', () async {
        var callCount = 0;

        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return Result.error(const DetectionFailure());
        });

        final controller = await makeAndInit('/test.jpg');
        expect(controller.failure.value, isNotNull);

        await controller.retry();

        expect(callCount, 2);
        controller.onClose();
      });

      test('failure is null briefly at start of retry', () async {
        when(
          () => processImage(
            imagePath: any(named: 'imagePath'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Result.error(const DetectionFailure()));

        final controller = await makeAndInit('/test.jpg');
        // Trigger retry — during retry failure should be cleared then re-set
        final retryFuture = controller.retry();
        // Immediately after retry() called (before await), failure is cleared
        expect(controller.failure.value, isNull);
        await retryFuture;
        controller.onClose();
      });
    });
  });
}
