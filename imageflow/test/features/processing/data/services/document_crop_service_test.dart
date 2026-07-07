import 'dart:io';

import 'package:document_scan/document_scan.dart' as ds;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imageflow/core/models/normalized_corners.dart';
import 'package:imageflow/features/processing/data/services/document_crop_service.dart';
import 'package:imageflow/features/processing/domain/entities/recognized_text_data.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetector extends Mock implements ds.DocumentDetector {}

void main() {
  // Isolate.run (used by the crop/filter branches) needs a test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // `detect(any())` needs a fallback for its positional ScanInput arg.
    registerFallbackValue(ds.ScanInput.file('fallback'));
  });

  late Directory dir;
  late String sourcePath;
  late String targetPath;
  late _MockDetector detector;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('docrop_test_');
    sourcePath = '${dir.path}/src.jpg';
    targetPath = '${dir.path}/out.jpg';
    // A real, decodable 60x60 JPEG so the isolate-side crop/filter can decode
    // it. Isolate.run re-runs the closure in a fresh isolate, which actually
    // reads and decodes this file, so it must exist on disk.
    File(sourcePath).writeAsBytesSync(
      img.encodeJpg(img.Image(width: 60, height: 60)),
    );
    detector = _MockDetector();
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // Corners spanning the whole normalized image (0..1), so the package's warp
  // has a valid quad to work with on the 60x60 source.
  const fullCorners = NormalizedCorners(
    topLeft: (x: 0.0, y: 0.0),
    topRight: (x: 1.0, y: 0.0),
    bottomRight: (x: 1.0, y: 1.0),
    bottomLeft: (x: 0.0, y: 1.0),
  );

  void expectTargetWritten() {
    final out = File(targetPath);
    expect(out.existsSync(), isTrue, reason: 'target file should exist');
    expect(out.lengthSync(), greaterThan(0), reason: 'target should be non-empty');
  }

  group('DocumentCropService.processDocument', () {
    test('corners supplied → skips detection and writes target', () async {
      final sut = DocumentCropService(detector: detector);

      await sut.processDocument(
        sourcePath: sourcePath,
        targetPath: targetPath,
        corners: fullCorners,
      );

      // Detection must NOT run when corners are provided.
      verifyNever(() => detector.detect(any()));
      expectTargetWritten();
    });

    test('corners null, detector finds corners → uses them', () async {
      const detected = ds.DocumentCorners(
        topLeft: (x: 0.0, y: 0.0),
        topRight: (x: 1.0, y: 0.0),
        bottomRight: (x: 1.0, y: 1.0),
        bottomLeft: (x: 0.0, y: 1.0),
      );
      when(() => detector.detect(any())).thenAnswer((_) async => detected);
      final sut = DocumentCropService(detector: detector);

      await sut.processDocument(
        sourcePath: sourcePath,
        targetPath: targetPath,
      );

      verify(() => detector.detect(any())).called(1);
      expectTargetWritten();
    });

    test('detector throws → falls back gracefully (text-block crop)', () async {
      when(() => detector.detect(any())).thenThrow(Exception('boom'));
      final sut = DocumentCropService(detector: detector);

      const recognized = RecognizedTextData(
        text: 'hello world',
        blockBoxes: [
          (left: 10, top: 10, right: 40, bottom: 40),
        ],
      );

      // Must not throw despite the detection failure.
      await expectLater(
        sut.processDocument(
          sourcePath: sourcePath,
          targetPath: targetPath,
          recognizedText: recognized,
        ),
        completes,
      );

      expectTargetWritten();
    });

    test('no corners + no text → whole-image filter fallback', () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);
      final sut = DocumentCropService(detector: detector);

      await sut.processDocument(
        sourcePath: sourcePath,
        targetPath: targetPath,
        // recognizedText null → filter-only branch.
      );

      verify(() => detector.detect(any())).called(1);
      expectTargetWritten();
    });

    test('text-block fallback produces a cropped (smaller) output', () async {
      when(() => detector.detect(any())).thenAnswer((_) async => null);
      final sut = DocumentCropService(detector: detector);

      // A single small block: 10..40 x 10..40 (30px). With a 10% margin
      // (3px each side) the crop region is ~7..43 → 36px, well under the
      // 60px source, so the output must be smaller in both dimensions.
      const recognized = RecognizedTextData(
        text: 'block',
        blockBoxes: [
          (left: 10, top: 10, right: 40, bottom: 40),
        ],
      );

      await sut.processDocument(
        sourcePath: sourcePath,
        targetPath: targetPath,
        recognizedText: recognized,
      );

      expectTargetWritten();

      final decoded = img.decodeJpg(File(targetPath).readAsBytesSync());
      expect(decoded, isNotNull);
      // Proves an actual crop happened rather than a whole-image passthrough.
      expect(decoded!.width, lessThan(60));
      expect(decoded.height, lessThan(60));
    });
  });
}
