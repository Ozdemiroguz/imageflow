import 'package:document_scan/document_scan.dart' as ds;
import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/services/document_scan_corner_detector.dart';
import 'package:mocktail/mocktail.dart';

class _MockDocumentDetector extends Mock implements ds.DocumentDetector {}

void main() {
  setUpAll(() {
    // `detect(any())` needs a fallback for its positional ScanInput arg.
    registerFallbackValue(ds.ScanInput.file('fallback'));
  });

  late _MockDocumentDetector detector;
  late DocumentScanCornerDetector sut;

  setUp(() {
    detector = _MockDocumentDetector();
    sut = DocumentScanCornerDetector(detector: detector);
  });

  group('detectCornersFromFrame', () {
    test('maps package corners field-for-field into NormalizedCorners', () async {
      // Distinct x/y per corner so a swapped field (or x<->y) would fail.
      const corners = ds.DocumentCorners(
        topLeft: (x: 0.11, y: 0.12),
        topRight: (x: 0.21, y: 0.22),
        bottomRight: (x: 0.31, y: 0.32),
        bottomLeft: (x: 0.41, y: 0.42),
      );
      when(() => detector.detect(any())).thenAnswer((_) async => corners);

      final result = await sut.detectCornersFromFrame(
        width: 640,
        height: 480,
        rotation: 0,
      );

      expect(result, isNotNull);
      expect(result!.topLeft.x, 0.11);
      expect(result.topLeft.y, 0.12);
      expect(result.topRight.x, 0.21);
      expect(result.topRight.y, 0.22);
      expect(result.bottomRight.x, 0.31);
      expect(result.bottomRight.y, 0.32);
      expect(result.bottomLeft.x, 0.41);
      expect(result.bottomLeft.y, 0.42);
      verify(() => detector.detect(any())).called(1);
    });

    test('returns null when the detector returns null', () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);

      final result = await sut.detectCornersFromFrame(
        width: 640,
        height: 480,
        rotation: 0,
      );

      expect(result, isNull);
    });

    test('returns null when the detector throws (dropped frame)', () async {
      when(() => detector.detect(any())).thenThrow(Exception('boom'));

      final result = await sut.detectCornersFromFrame(
        width: 640,
        height: 480,
        rotation: 0,
      );

      expect(result, isNull);
    });

    test("format 'yuv420' builds a yuv420 camera-frame ScanInput", () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);

      await sut.detectCornersFromFrame(
        width: 640,
        height: 480,
        rotation: 90,
        format: 'yuv420',
      );

      final input =
          verify(() => detector.detect(captureAny())).captured.single
              as ds.CameraFrameScanInput;
      expect(input.format, ds.ScanImageFormat.yuv420);
      expect(input.rotation, 90);
      expect(input.width, 640);
      expect(input.height, 480);
    });

    test('default format builds a bgra8888 camera-frame ScanInput', () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);

      await sut.detectCornersFromFrame(
        width: 320,
        height: 240,
        rotation: 0,
      );

      final input =
          verify(() => detector.detect(captureAny())).captured.single
              as ds.CameraFrameScanInput;
      expect(input.format, ds.ScanImageFormat.bgra8888);
    });

    test('any non-yuv420 format falls back to bgra8888', () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);

      await sut.detectCornersFromFrame(
        width: 320,
        height: 240,
        rotation: 0,
        format: 'bgra',
      );

      final input =
          verify(() => detector.detect(captureAny())).captured.single
              as ds.CameraFrameScanInput;
      expect(input.format, ds.ScanImageFormat.bgra8888);
    });
  });
}
