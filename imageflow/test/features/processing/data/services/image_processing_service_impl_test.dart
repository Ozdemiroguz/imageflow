import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/models/detected_face.dart';
import 'package:imageflow/core/models/face_geometry.dart';
import 'package:imageflow/core/models/normalized_corners.dart';
import 'package:imageflow/core/services/file_service.dart';
import 'package:imageflow/features/processing/data/services/image_processing_service_impl.dart';
import 'package:imageflow/features/processing/domain/entities/detection_result.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/processing/domain/entities/recognized_text_data.dart';
import 'package:imageflow/features/processing/domain/services/content_detector.dart';
import 'package:imageflow/features/processing/domain/services/document_cropper.dart';
import 'package:imageflow/features/processing/domain/services/face_annotator.dart';
import 'package:mocktail/mocktail.dart';

class _MockFileService extends Mock implements FileService {}

class _MockContentDetector extends Mock implements ContentDetector {}

class _MockDocumentCropper extends Mock implements DocumentCropper {}

class _MockFaceAnnotator extends Mock implements FaceAnnotator {}

// ---------------------------------------------------------------------------
// Helpers to build the domain fakes the pipeline consumes.
// ---------------------------------------------------------------------------

DetectionResult _documentDetection({String text = 'ORIGINAL'}) =>
    DetectionResult(
      type: ProcessingType.document,
      recognizedText: RecognizedTextData(text: text),
    );

DetectionResult _faceDetection() => const DetectionResult(
  type: ProcessingType.face,
  faces: [
    DetectedFace(
      boundingBox: (left: 5, top: 5, right: 25, bottom: 25),
      contour: [(x: 5, y: 5), (x: 25, y: 5), (x: 25, y: 25), (x: 5, y: 25)],
    ),
  ],
);

const _corners = NormalizedCorners(
  topLeft: (x: 0.1, y: 0.1),
  topRight: (x: 0.9, y: 0.1),
  bottomRight: (x: 0.9, y: 0.9),
  bottomLeft: (x: 0.1, y: 0.9),
);

/// Unwraps an [Ok] result or fails the test with the underlying failure.
ProcessingResult _expectOk(Result<ProcessingResult> result) {
  expect(
    result,
    isA<Ok<ProcessingResult>>(),
    reason: 'expected Ok, got $result',
  );
  return (result as Ok<ProcessingResult>).value;
}

void main() {
  late _MockFileService fileService;
  late _MockContentDetector contentDetector;
  late _MockDocumentCropper documentCropper;
  late _MockFaceAnnotator faceAnnotator;
  late ImageProcessingServiceImpl service;

  late Directory tempDir;
  late String inputImagePath;

  setUpAll(() {
    registerFallbackValue(_corners);
    registerFallbackValue(const RecognizedTextData(text: ''));
    registerFallbackValue(ProcessingType.document);
    registerFallbackValue(<FaceRect>[]);
    registerFallbackValue(<List<ContourPoint>>[]);
  });

  setUp(() {
    fileService = _MockFileService();
    contentDetector = _MockContentDetector();
    documentCropper = _MockDocumentCropper();
    faceAnnotator = _MockFaceAnnotator();

    tempDir = Directory.systemTemp.createTempSync('improc_test_');

    // A real, decodable tiny JPEG so File.copy, thumbnail generation, rotation
    // and PDF generation all operate on valid bytes.
    inputImagePath = '${tempDir.path}/input.jpg';
    File(
      inputImagePath,
    ).writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 40)));

    // Every uuid the service mints maps into the temp dir. `_work` copies land
    // in the same dir with distinct names because the uuid string differs.
    when(() => fileService.originalFilePath(any())).thenAnswer(
      (inv) => '${tempDir.path}/${inv.positionalArguments.first}_orig.jpg',
    );
    when(() => fileService.processedFilePath(any())).thenAnswer(
      (inv) => '${tempDir.path}/${inv.positionalArguments.first}_proc.jpg',
    );
    when(() => fileService.pdfFilePath(any())).thenAnswer(
      (inv) => '${tempDir.path}/${inv.positionalArguments.first}.pdf',
    );
    when(() => fileService.thumbnailFilePath(any())).thenAnswer(
      (inv) => '${tempDir.path}/${inv.positionalArguments.first}_thumb.jpg',
    );

    // The cropper's contract is to write a valid image to targetPath; copy the
    // decodable input so downstream steps (orientation, PDF, thumbnail) work.
    when(
      () => documentCropper.processDocument(
        sourcePath: any(named: 'sourcePath'),
        targetPath: any(named: 'targetPath'),
        recognizedText: any(named: 'recognizedText'),
        corners: any(named: 'corners'),
      ),
    ).thenAnswer((inv) async {
      final target = inv.namedArguments[#targetPath] as String;
      await File(inputImagePath).copy(target);
      // Default: report a real crop so the second OCR pass runs (the tests that
      // exercise refined text rely on it). The filter-only case is covered by
      // its own test that overrides this stub.
      return DocumentCropOutcome.geometryChanged;
    });

    // Same contract for the face annotator.
    when(
      () => faceAnnotator.annotate(
        sourcePath: any(named: 'sourcePath'),
        targetPath: any(named: 'targetPath'),
        rects: any(named: 'rects'),
        contours: any(named: 'contours'),
      ),
    ).thenAnswer((inv) async {
      final target = inv.namedArguments[#targetPath] as String;
      await File(inputImagePath).copy(target);
    });

    service = ImageProcessingServiceImpl(
      fileService: fileService,
      contentDetector: contentDetector,
      documentCropper: documentCropper,
      faceAnnotator: faceAnnotator,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Stubs detect for every imagePath with a single response.
  void stubDetect(DetectionResult result) {
    when(
      () => contentDetector.detect(
        imagePath: any(named: 'imagePath'),
        preferredType: any(named: 'preferredType'),
        allowRotationFallback: any(named: 'allowRotationFallback'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('ImageProcessingServiceImpl.processImage', () {
    test('forceDocument routing: corners + face detection routes to DOCUMENT, '
        'not FACE (the ID-card fix)', () async {
      // Detection insists this is a face (an ID card carries a photo), but
      // the user confirmed corners → it must be cropped as a document.
      stubDetect(_faceDetection());

      final result = await service.processImage(
        imagePath: inputImagePath,
        corners: _corners,
      );

      final value = _expectOk(result);
      expect(value.type, ProcessingType.document);
      verifyNever(
        () => faceAnnotator.annotate(
          sourcePath: any(named: 'sourcePath'),
          targetPath: any(named: 'targetPath'),
          rects: any(named: 'rects'),
          contours: any(named: 'contours'),
        ),
      );
      verify(
        () => documentCropper.processDocument(
          sourcePath: any(named: 'sourcePath'),
          targetPath: any(named: 'targetPath'),
          recognizedText: any(named: 'recognizedText'),
          corners: any(named: 'corners'),
        ),
      ).called(1);
    });

    test(
      'effectivePreferredType: corners force preferredType == document on detect',
      () async {
        stubDetect(_documentDetection());

        await service.processImage(
          imagePath: inputImagePath,
          corners: _corners,
        );

        final captured = verify(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: captureAny(named: 'preferredType'),
            allowRotationFallback: any(named: 'allowRotationFallback'),
          ),
        ).captured;
        // First detect pass (on the working copy) must be forced to document.
        expect(captured.first, ProcessingType.document);
      },
    );

    test(
      'corners are passed through to documentCropper.processDocument',
      () async {
        stubDetect(_documentDetection());

        await service.processImage(
          imagePath: inputImagePath,
          corners: _corners,
        );

        final captured = verify(
          () => documentCropper.processDocument(
            sourcePath: any(named: 'sourcePath'),
            targetPath: any(named: 'targetPath'),
            recognizedText: any(named: 'recognizedText'),
            corners: captureAny(named: 'corners'),
          ),
        ).captured;
        expect(captured.single, same(_corners));
      },
    );

    test(
      'corners supplied → every detect uses allowRotationFallback: false '
      '(so a pre-crop rotation cannot invalidate the upright-space corners)',
      () async {
        stubDetect(_documentDetection());

        await service.processImage(
          imagePath: inputImagePath,
          corners: _corners,
        );

        final captured = verify(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: captureAny(named: 'allowRotationFallback'),
          ),
        ).captured;
        // Both the initial detect and the post-crop OCR read must be false.
        expect(captured, everyElement(isFalse));
      },
    );

    test(
      'no corners → initial detect keeps allowRotationFallback: true, but the '
      'post-crop OCR read is always false',
      () async {
        stubDetect(_documentDetection());

        await service.processImage(imagePath: inputImagePath);

        final captured = verify(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: captureAny(named: 'allowRotationFallback'),
          ),
        ).captured;
        // First pass (working copy) keeps the fallback enabled for the
        // automatic flow; the post-crop OCR read never rotates the result.
        expect(captured.first, isTrue);
        expect(captured.last, isFalse);
      },
    );

    test('extractedText fallback: refined post-crop OCR text wins', () async {
      // First detect runs on the *_work copy → ORIGINAL.
      // Post-crop detect runs on the *_proc copy → REFINED.
      when(
        () => contentDetector.detect(
          imagePath: any(named: 'imagePath'),
          preferredType: any(named: 'preferredType'),
          allowRotationFallback: any(named: 'allowRotationFallback'),
        ),
      ).thenAnswer((inv) async {
        final path = inv.namedArguments[#imagePath] as String;
        // The working copy uuid is '${id}_work'; the processed copy is just
        // '$id'. Discriminate on '_work' so the post-crop pass (on the
        // processed image) is the only one that returns REFINED.
        final text = path.contains('_work') ? 'ORIGINAL' : 'REFINED';
        return _documentDetection(text: text);
      });

      final result = await service.processImage(
        imagePath: inputImagePath,
        corners: _corners,
      );

      expect(_expectOk(result).extractedText, 'REFINED');
    });

    test(
      'extractedText fallback: falls back to original text when refined is empty',
      () async {
        when(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: any(named: 'allowRotationFallback'),
          ),
        ).thenAnswer((inv) async {
          final path = inv.namedArguments[#imagePath] as String;
          // The working copy uuid is '${id}_work'; the processed copy is just
          // '$id'. The post-crop pass (processed image, no '_work') finds
          // nothing → keep the original-image text.
          if (path.contains('_work')) {
            return _documentDetection(text: 'ORIGINAL');
          }
          return _documentDetection(text: '');
        });

        final result = await service.processImage(
          imagePath: inputImagePath,
          corners: _corners,
        );

        expect(_expectOk(result).extractedText, 'ORIGINAL');
      },
    );

    test(
      'double-OCR gate: filter-only crop + no rotation → post-crop OCR skipped',
      () async {
        // The cropper reports it only recolored the image (no warp/crop), and
        // detection applied no rotation → the processed pixels match what the
        // first pass already OCR'd, so the second pass must not run.
        when(
          () => documentCropper.processDocument(
            sourcePath: any(named: 'sourcePath'),
            targetPath: any(named: 'targetPath'),
            recognizedText: any(named: 'recognizedText'),
            corners: any(named: 'corners'),
          ),
        ).thenAnswer((inv) async {
          await File(
            inputImagePath,
          ).copy(inv.namedArguments[#targetPath] as String);
          return DocumentCropOutcome.filterOnly;
        });
        stubDetect(_documentDetection(text: 'ORIGINAL')); // appliedRotation: 0

        final result = await service.processImage(imagePath: inputImagePath);

        // Text still comes through (from the first pass) ...
        expect(_expectOk(result).extractedText, 'ORIGINAL');
        // ... and detection ran exactly once — the working-copy pass only; the
        // processed-image (non-'_work') pass was skipped.
        verify(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: any(named: 'allowRotationFallback'),
          ),
        ).called(1);
      },
    );

    test(
      'double-OCR gate: filter-only crop BUT rotation applied → post-crop OCR '
      'still runs',
      () async {
        when(
          () => documentCropper.processDocument(
            sourcePath: any(named: 'sourcePath'),
            targetPath: any(named: 'targetPath'),
            recognizedText: any(named: 'recognizedText'),
            corners: any(named: 'corners'),
          ),
        ).thenAnswer((inv) async {
          await File(
            inputImagePath,
          ).copy(inv.namedArguments[#targetPath] as String);
          return DocumentCropOutcome.filterOnly;
        });
        // Rotation was undone → the processed image differs from the source, so
        // re-OCR can help even though the crop only filtered.
        when(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: any(named: 'allowRotationFallback'),
          ),
        ).thenAnswer((inv) async {
          final path = inv.namedArguments[#imagePath] as String;
          if (path.contains('_work')) {
            return const DetectionResult(
              type: ProcessingType.document,
              recognizedText: RecognizedTextData(text: 'ORIGINAL'),
              appliedRotation: 90,
            );
          }
          return _documentDetection(text: 'REFINED');
        });

        final result = await service.processImage(imagePath: inputImagePath);

        expect(_expectOk(result).extractedText, 'REFINED');
        verify(
          () => contentDetector.detect(
            imagePath: any(named: 'imagePath'),
            preferredType: any(named: 'preferredType'),
            allowRotationFallback: any(named: 'allowRotationFallback'),
          ),
        ).called(2);
      },
    );

    test('no content and no corners → DetectionFailure error', () async {
      stubDetect(const DetectionResult(type: null));

      final result = await service.processImage(imagePath: inputImagePath);

      expect(result, isA<Error<ProcessingResult>>());
      expect(
        (result as Error<ProcessingResult>).failure,
        isA<DetectionFailure>(),
      );
    });

    test('no content BUT corners given → still succeeds as document '
        '(forceDocument overrides the throw)', () async {
      stubDetect(const DetectionResult(type: null));

      final result = await service.processImage(
        imagePath: inputImagePath,
        corners: _corners,
      );

      final value = _expectOk(result);
      expect(value.type, ProcessingType.document);
      verify(
        () => documentCropper.processDocument(
          sourcePath: any(named: 'sourcePath'),
          targetPath: any(named: 'targetPath'),
          recognizedText: any(named: 'recognizedText'),
          corners: any(named: 'corners'),
        ),
      ).called(1);
    });

    test('face flow: faces present, no corners → annotate called, cropper not, '
        'type face with null extractedText', () async {
      stubDetect(_faceDetection());

      final result = await service.processImage(imagePath: inputImagePath);

      final value = _expectOk(result);
      expect(value.type, ProcessingType.face);
      expect(value.extractedText, isNull);
      expect(value.facesDetected, 1);
      verify(
        () => faceAnnotator.annotate(
          sourcePath: any(named: 'sourcePath'),
          targetPath: any(named: 'targetPath'),
          rects: any(named: 'rects'),
          contours: any(named: 'contours'),
        ),
      ).called(1);
      verifyNever(
        () => documentCropper.processDocument(
          sourcePath: any(named: 'sourcePath'),
          targetPath: any(named: 'targetPath'),
          recognizedText: any(named: 'recognizedText'),
          corners: any(named: 'corners'),
        ),
      );
    });
  });
}
