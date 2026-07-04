import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:imageflow/core/platform/corner_detector.dart';
import 'package:imageflow/core/platform/object_detector.dart';
import 'package:imageflow/features/realtime/data/datasources/realtime_face_detection_service.dart';
import 'package:imageflow/features/realtime/data/datasources/realtime_ocr_gate_service.dart';
import 'package:imageflow/features/realtime/data/services/realtime_detection_pipeline.dart';
import 'package:imageflow/features/realtime/data/services/detection_output_port.dart';
import 'package:imageflow/features/realtime/data/services/realtime_detection_scheduler.dart';
import 'package:imageflow/features/realtime/data/services/realtime_preview_builder.dart';
import 'package:mocktail/mocktail.dart';

/// Characterization tests for the realtime detection pipeline.
///
/// These lock the pipeline's *outputs to the overlay store* for the stable,
/// no-detection branches (no text / no face / no corner). They are the safety
/// net for the data->presentation dependency inversion: the pipeline is being
/// switched from depending on the concrete store to a DetectionOutputPort, and
/// these assertions must stay green because behavior does not change — only the
/// dependency direction does.
class _MockOutputPort extends Mock implements DetectionOutputPort {}

class _MockCornerDetector extends Mock implements CornerDetector {}

class _MockObjectDetector extends Mock implements ObjectDetector {}

class _MockFaceDetectionService extends Mock
    implements RealtimeFaceDetectionService {}

class _MockOcrGateService extends Mock implements RealtimeOcrGateService {}

class _MockPreviewBuilder extends Mock implements RealtimePreviewBuilder {}

class _FakeCameraImage extends Mock implements CameraImage {}

class _FallbackCameraImage extends Fake implements CameraImage {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FallbackCameraImage());
    registerFallbackValue(InputImageRotation.rotation0deg);
  });

  late _MockOutputPort output;
  late _MockCornerDetector cornerDetector;
  late _MockObjectDetector objectDetector;
  late _MockFaceDetectionService faceService;
  late _MockOcrGateService ocrService;
  late _MockPreviewBuilder previewBuilder;
  late RealtimeDetectionScheduler scheduler;
  late RealtimeDetectionPipeline pipeline;
  late _FakeCameraImage frame;

  const noTextStatus = 'No document';
  const scanningStatus = 'Scanning for document...';

  setUp(() {
    output = _MockOutputPort();
    cornerDetector = _MockCornerDetector();
    objectDetector = _MockObjectDetector();
    faceService = _MockFaceDetectionService();
    ocrService = _MockOcrGateService();
    previewBuilder = _MockPreviewBuilder();
    frame = _FakeCameraImage();

    // A scheduler whose intervals are all zero so nothing is throttled out.
    scheduler = RealtimeDetectionScheduler(
      faceInterval: Duration.zero,
      ocrInterval: Duration.zero,
      edgeInterval: Duration.zero,
      objectInterval: Duration.zero,
      facePanelInterval: Duration.zero,
      documentPanelInterval: Duration.zero,
    );

    pipeline = RealtimeDetectionPipeline(
      imageFormatGroup: ImageFormatGroup.yuv420,
      frameImageUsesNativeRotation: true,
      documentNoTextStatus: noTextStatus,
      documentScanningStatus: scanningStatus,
      scheduler: scheduler,
      output: output,
      cornerDetectionService: cornerDetector,
      objectDetectionService: objectDetector,
      faceDetectionService: faceService,
      ocrGateService: ocrService,
      previewBuilder: previewBuilder,
    );
  });

  group('runOcrGate', () {
    test('no text -> setDocumentNoTextState', () async {
      when(
        () => ocrService.evaluate(
          frame: any(named: 'frame'),
          rotation: any(named: 'rotation'),
          androidNv21Bytes: any(named: 'androidNv21Bytes'),
          preparedInputImage: any(named: 'preparedInputImage'),
        ),
      ).thenAnswer((_) async => (hasText: false));

      await pipeline.runOcrGate(
        frame,
        rotation: InputImageRotation.rotation0deg,
      );

      verify(() => output.setDocumentNoTextState()).called(1);
      verifyNever(() => output.setDocumentSearchingState());
    });

    test(
      'has text and status is scanning -> setDocumentSearchingState',
      () async {
        when(
          () => ocrService.evaluate(
            frame: any(named: 'frame'),
            rotation: any(named: 'rotation'),
            androidNv21Bytes: any(named: 'androidNv21Bytes'),
            preparedInputImage: any(named: 'preparedInputImage'),
          ),
        ).thenAnswer((_) async => (hasText: true));
        when(() => output.documentStatusLabel).thenReturn(scanningStatus);

        await pipeline.runOcrGate(
          frame,
          rotation: InputImageRotation.rotation0deg,
        );

        verify(() => output.setDocumentSearchingState()).called(1);
        verifyNever(() => output.setDocumentNoTextState());
      },
    );
  });

  group('runFaceDetection', () {
    test(
      'no faces -> applyFaceGeometry empty + setFaceNotFoundState',
      () async {
        when(
          () => faceService.detect(
            frame: any(named: 'frame'),
            rotation: any(named: 'rotation'),
            androidNv21Bytes: any(named: 'androidNv21Bytes'),
            preparedInputImage: any(named: 'preparedInputImage'),
          ),
        ).thenAnswer((_) async => const <Face>[]);

        await pipeline.runFaceDetection(
          frame,
          rotation: InputImageRotation.rotation0deg,
          nativeRotationDegrees: 0,
          frameImageRotationDegrees: 0,
          needsMirrorCompensation: false,
        );

        verify(
          () => output.applyFaceGeometry(
            nextFaceRects: const [],
            nextFaceContours: const [],
          ),
        ).called(1);
        verify(() => output.setFaceNotFoundState()).called(1);
        verifyNever(() => output.setFaceDetectedStatus(any()));
      },
    );
  });

  group('runDocumentEdgeDetection', () {
    test('no corner -> clears corners + setDocumentSearchingState', () async {
      when(
        () => cornerDetector.detectCornersFromFrame(
          width: any(named: 'width'),
          height: any(named: 'height'),
          rotation: any(named: 'rotation'),
          bytes: any(named: 'bytes'),
          bytesPerRow: any(named: 'bytesPerRow'),
          yBytes: any(named: 'yBytes'),
          uBytes: any(named: 'uBytes'),
          vBytes: any(named: 'vBytes'),
          yRowStride: any(named: 'yRowStride'),
          uvRowStride: any(named: 'uvRowStride'),
          uvPixelStride: any(named: 'uvPixelStride'),
          format: any(named: 'format'),
        ),
      ).thenAnswer((_) async => null);
      // yuv420 path needs >=3 planes; give it a valid-shaped frame.
      when(() => frame.planes).thenReturn(const []);

      await pipeline.runDocumentEdgeDetection(
        frame,
        nativeRotationDegrees: 0,
        frameImageRotationDegrees: 0,
        isFrontCamera: false,
        needsMirrorCompensation: false,
      );

      verify(() => output.setDocumentCorners(null)).called(1);
      verify(() => output.setDocumentPreviewBytes(null)).called(1);
      verify(() => output.resetDocumentPreviewMotionState()).called(1);
      verify(() => output.setDocumentSearchingState()).called(1);
      verifyNever(() => output.setDocumentFoundState());
    });
  });

  group('runObjectDetection', () {
    test('empty frame -> publishes empty list, never calls native', () async {
      // No planes: object detection short-circuits to [] without a channel hop.
      when(() => frame.planes).thenReturn(const []);

      await pipeline.runObjectDetection(frame, nativeRotationDegrees: 0);

      verify(() => output.setDetectedObjects(const [])).called(1);
      verifyNever(
        () => objectDetector.detectObjectsFromFrame(
          width: any(named: 'width'),
          height: any(named: 'height'),
          rotation: any(named: 'rotation'),
          bytes: any(named: 'bytes'),
          bytesPerRow: any(named: 'bytesPerRow'),
          yBytes: any(named: 'yBytes'),
          uBytes: any(named: 'uBytes'),
          vBytes: any(named: 'vBytes'),
          yRowStride: any(named: 'yRowStride'),
          uvRowStride: any(named: 'uvRowStride'),
          uvPixelStride: any(named: 'uvPixelStride'),
          format: any(named: 'format'),
        ),
      );
    });

    test('native error still releases the scheduler slot', () async {
      // Guarded: even if reading the frame throws, the object slot must be
      // released so the next frame is not permanently blocked.
      final t0 = DateTime(2026, 1, 1, 12);
      when(() => frame.planes).thenThrow(StateError('boom'));

      // Occupy the slot the way processFrame would before delegating.
      expect(scheduler.tryBeginObjectDetection(t0), isTrue);
      await pipeline.runObjectDetection(frame, nativeRotationDegrees: 0);

      // Slot was released by runObjectDetection's endObjectDetection().
      expect(
        scheduler.tryBeginObjectDetection(t0.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
