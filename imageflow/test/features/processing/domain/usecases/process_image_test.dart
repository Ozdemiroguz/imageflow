import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/processing/domain/entities/processing_step.dart';
import 'package:imageflow/features/processing/domain/services/image_processing_service.dart';
import 'package:imageflow/features/processing/domain/usecases/process_image.dart';
import 'package:mocktail/mocktail.dart';

class _MockImageProcessingService extends Mock implements ImageProcessingService {}

ProcessingResult _fakeResult() => ProcessingResult(
  id: 'test-id',
  type: ProcessingType.face,
  originalImagePath: '/originals/test.jpg',
  processedImagePath: '/processed/test.jpg',
  thumbnailPath: '/thumbnails/test_thumb.jpg',
  fileSizeBytes: 1024,
  createdAt: DateTime(2024),
);

void main() {
  late _MockImageProcessingService service;
  late ProcessImage useCase;

  setUp(() {
    service = _MockImageProcessingService();
    useCase = ProcessImage(service);
  });

  group('ProcessImage', () {
    test(
      'delegates to service.processImage with required imagePath',
      () async {
        when(
          () => service.processImage(
            imagePath: '/test.jpg',
            preferredType: null,
            onProgress: null,
            capturedWithFrontCamera: null,
          ),
        ).thenAnswer((_) async => Result.ok(_fakeResult()));

        await useCase(imagePath: '/test.jpg');

        verify(
          () => service.processImage(
            imagePath: '/test.jpg',
            preferredType: null,
            onProgress: null,
            capturedWithFrontCamera: null,
          ),
        ).called(1);
      },
    );

    test('passes preferredType: document to service', () async {
      when(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: ProcessingType.document,
          onProgress: null,
          capturedWithFrontCamera: null,
        ),
      ).thenAnswer((_) async => Result.ok(_fakeResult()));

      await useCase(
        imagePath: '/test.jpg',
        preferredType: ProcessingType.document,
      );

      verify(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: ProcessingType.document,
          onProgress: null,
          capturedWithFrontCamera: null,
        ),
      ).called(1);
    });

    test('passes capturedWithFrontCamera to service', () async {
      when(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: null,
          onProgress: null,
          capturedWithFrontCamera: true,
        ),
      ).thenAnswer((_) async => Result.ok(_fakeResult()));

      await useCase(imagePath: '/test.jpg', capturedWithFrontCamera: true);

      verify(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: null,
          onProgress: null,
          capturedWithFrontCamera: true,
        ),
      ).called(1);
    });

    test('passes onProgress callback through to service', () async {
      ProcessingStep? capturedStep;
      void onProgress(ProcessingStep step) => capturedStep = step;

      when(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: null,
          onProgress: onProgress,
          capturedWithFrontCamera: null,
        ),
      ).thenAnswer((invocation) async {
        final cb = invocation.namedArguments[#onProgress] as ProgressCallback?;
        cb?.call(ProcessingStep.detectingFaces);
        return Result.ok(_fakeResult());
      });

      await useCase(imagePath: '/test.jpg', onProgress: onProgress);

      expect(capturedStep, ProcessingStep.detectingFaces);
    });

    test('returns Ok<ProcessingResult> on success', () async {
      final expected = _fakeResult();

      when(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: null,
          onProgress: null,
          capturedWithFrontCamera: null,
        ),
      ).thenAnswer((_) async => Result.ok(expected));

      final result = await useCase(imagePath: '/test.jpg');

      expect(result.isOk, isTrue);
      expect((result as Ok<ProcessingResult>).value, same(expected));
    });

    test('returns Error when service returns DetectionFailure', () async {
      when(
        () => service.processImage(
          imagePath: '/test.jpg',
          preferredType: null,
          onProgress: null,
          capturedWithFrontCamera: null,
        ),
      ).thenAnswer((_) async => Result.error(const DetectionFailure()));

      final result = await useCase(imagePath: '/test.jpg');

      expect(result.isError, isTrue);
      expect(
        (result as Error<ProcessingResult>).failure,
        isA<DetectionFailure>(),
      );
    });

    test(
      'null preferredType triggers auto-detection mode (no type passed)',
      () async {
        when(
          () => service.processImage(
            imagePath: any(named: 'imagePath'),
            preferredType: null,
            onProgress: null,
            capturedWithFrontCamera: null,
          ),
        ).thenAnswer((_) async => Result.ok(_fakeResult()));

        final result = await useCase(imagePath: '/auto.jpg');

        expect(result.isOk, isTrue);
        verify(
          () => service.processImage(
            imagePath: '/auto.jpg',
            preferredType: null,
            onProgress: null,
            capturedWithFrontCamera: null,
          ),
        ).called(1);
      },
    );
  });
}
