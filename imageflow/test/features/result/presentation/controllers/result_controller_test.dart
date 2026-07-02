import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/coordinators/document_actions_presenter.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/services/pdf_raster/pdf_raster_service.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/result/presentation/controllers/result_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockDocumentActions extends Mock implements DocumentActionsPresenter {}

class _MockPdfRasterService extends Mock implements PdfRasterService {}

ProcessingResult _result({
  ProcessingType type = ProcessingType.document,
  String? pdfPath = '/doc.pdf',
}) => ProcessingResult(
  id: 'r1',
  type: type,
  originalImagePath: '/o.jpg',
  processedImagePath: '/p.jpg',
  thumbnailPath: '/t.jpg',
  fileSizeBytes: 10,
  createdAt: DateTime(2026),
  extractedText: 'hello',
  facesDetected: 0,
  faceRects: const [],
  faceContours: const [],
  pdfPath: pdfPath,
);

ProcessingHistory _history() => ProcessingHistory(
  id: 'h1',
  type: ProcessingType.document,
  originalImagePath: '/ho.jpg',
  processedImagePath: '/hp.jpg',
  thumbnailPath: '/ht.jpg',
  pdfPath: '/hdoc.pdf',
  fileSizeBytes: 20,
  createdAt: DateTime(2026),
  extractedText: 'from history',
  facesDetected: 0,
  faceRects: const [],
  faceContours: const [],
);

void main() {
  late _MockDocumentActions documentActions;
  late _MockPdfRasterService pdfRasterService;

  setUp(() {
    Get.testMode = true;
    documentActions = _MockDocumentActions();
    pdfRasterService = _MockPdfRasterService();
  });

  tearDown(Get.reset);

  ResultController makeAndInit(Object? args) {
    Get.routing.args = args;
    final controller = ResultController(
      documentActions: documentActions,
      pdfRasterService: pdfRasterService,
    );
    controller.onInit();
    return controller;
  }

  group('onInit route argument handling', () {
    test('ProcessingResult argument is used directly, no failure', () {
      final controller = makeAndInit(_result());
      expect(controller.failure.value, isNull);
      expect(controller.result.id, 'r1');
      expect(controller.isDocument, isTrue);
      expect(controller.isFace, isFalse);
    });

    test('ProcessingHistory argument is mapped into a result', () {
      final controller = makeAndInit(_history());
      expect(controller.failure.value, isNull);
      expect(controller.result.id, 'h1');
      expect(controller.result.extractedText, 'from history');
    });

    test('bad argument sets failure instead of throwing', () {
      final controller = makeAndInit('not a result');
      expect(controller.failure.value, isA<RouteArgumentFailure>());
    });

    test('null argument sets failure', () {
      final controller = makeAndInit(null);
      expect(controller.failure.value, isA<RouteArgumentFailure>());
    });
  });

  group('derived getters', () {
    test('isFace true for a face result', () {
      final controller = makeAndInit(_result(type: ProcessingType.face));
      expect(controller.isFace, isTrue);
      expect(controller.isDocument, isFalse);
    });

    test('hasPdf reflects a non-empty pdf path', () {
      expect(makeAndInit(_result(pdfPath: '/doc.pdf')).hasPdf, isTrue);
      expect(makeAndInit(_result(pdfPath: null)).hasPdf, isFalse);
      expect(makeAndInit(_result(pdfPath: '   ')).hasPdf, isFalse);
    });
  });

  group('actions delegate to DocumentActionsPresenter', () {
    test('openPdfExternally forwards the pdf path', () async {
      when(
        () => documentActions.openPdfExternally(any()),
      ).thenAnswer((_) async {});
      final controller = makeAndInit(_result(pdfPath: '/doc.pdf'));

      await controller.openPdfExternally();

      verify(() => documentActions.openPdfExternally('/doc.pdf')).called(1);
    });

    test('showExtractedTextSheet forwards the text', () {
      when(() => documentActions.showExtractedTextSheet(any())).thenReturn(null);
      final controller = makeAndInit(_result());

      controller.showExtractedTextSheet();

      verify(() => documentActions.showExtractedTextSheet('hello')).called(1);
    });
  });
}
