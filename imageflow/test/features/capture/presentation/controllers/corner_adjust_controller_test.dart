import 'package:document_scan/document_scan.dart' as ds;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/features/capture/presentation/controllers/corner_adjust_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScanner extends Mock implements ds.DocumentScanner {}

ds.DocumentCorners _fakeCorners() => const ds.DocumentCorners(
  topLeft: (x: 0.1, y: 0.2),
  topRight: (x: 0.8, y: 0.15),
  bottomRight: (x: 0.85, y: 0.9),
  bottomLeft: (x: 0.05, y: 0.95),
);

void main() {
  late _MockScanner scanner;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(ds.ScanInput.file('x'));
  });

  setUp(() {
    scanner = _MockScanner();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  Future<CornerAdjustController> makeAndInit(Object? args) async {
    Get.routing.args = args;
    final controller = CornerAdjustController(scanner: scanner);
    controller.onInit();
    await pumpEventQueue();
    return controller;
  }

  group('CornerAdjustController', () {
    group('onInit', () {
      test('reads imagePath from a String arg', () async {
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => null);

        final controller = await makeAndInit('/photo.jpg');

        expect(controller.imagePath, '/photo.jpg');
        controller.onClose();
      });

      test('reads imagePath from a Map arg', () async {
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => null);

        final controller = await makeAndInit(<String, dynamic>{
          'imagePath': '/p.jpg',
          'capturedWithFrontCamera': true,
        });

        expect(controller.imagePath, '/p.jpg');
        controller.onClose();
      });
    });

    group('detection', () {
      test('maps package corners field-for-field and clears isDetecting', () async {
        final detected = _fakeCorners();
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => detected);

        final controller = await makeAndInit('/photo.jpg');

        final c = controller.corners.value;
        expect(c, isNotNull);
        expect(c!.topLeft, detected.topLeft);
        expect(c.topRight, detected.topRight);
        expect(c.bottomRight, detected.bottomRight);
        expect(c.bottomLeft, detected.bottomLeft);
        expect(controller.isDetecting.value, isFalse);
        controller.onClose();
      });

      test('leaves corners null when detection returns null', () async {
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => null);

        final controller = await makeAndInit('/photo.jpg');

        expect(controller.corners.value, isNull);
        controller.onClose();
      });

      test('swallows detection errors and treats them as no detection', () async {
        when(
          () => scanner.detectCorners(any()),
        ).thenThrow(Exception('boom'));

        final controller = await makeAndInit('/photo.jpg');

        expect(controller.corners.value, isNull);
        controller.onClose();
      });
    });

    group('moveCorner', () {
      test('clamps out-of-range values and leaves other corners unchanged', () async {
        final detected = _fakeCorners();
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => detected);

        final controller = await makeAndInit('/photo.jpg');

        controller.moveCorner(0, (x: 1.5, y: -0.3));

        final c = controller.corners.value!;
        expect(c.topLeft, (x: 1.0, y: 0.0));
        expect(c.topRight, detected.topRight);
        expect(c.bottomRight, detected.bottomRight);
        expect(c.bottomLeft, detected.bottomLeft);
        controller.onClose();
      });

      test('is a no-op when corners are null', () async {
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => null);

        final controller = await makeAndInit('/photo.jpg');

        expect(controller.corners.value, isNull);
        expect(
          () => controller.moveCorner(0, (x: 0.5, y: 0.5)),
          returnsNormally,
        );
        expect(controller.corners.value, isNull);
        controller.onClose();
      });

      test('index routing updates only the targeted corner', () async {
        final detected = _fakeCorners();
        when(
          () => scanner.detectCorners(any()),
        ).thenAnswer((_) async => detected);

        final controller = await makeAndInit('/photo.jpg');

        controller.moveCorner(2, (x: 0.42, y: 0.42));

        final c = controller.corners.value!;
        expect(c.bottomRight, (x: 0.42, y: 0.42));
        expect(c.topLeft, detected.topLeft);
        expect(c.topRight, detected.topRight);
        expect(c.bottomLeft, detected.bottomLeft);
        controller.onClose();
      });
    });
  });
}
