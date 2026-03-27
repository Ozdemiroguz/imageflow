import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/services/pdf_raster/pdf_raster_service.dart';
import 'package:imageflow/core/widgets/pdf/pdf_viewer_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPdfRasterService extends Mock implements PdfRasterService {}

void main() {
  group('PdfViewerController', () {
    const pdfPath = '/tmp/sample.pdf';
    late _MockPdfRasterService rasterService;
    late PdfViewerController controller;

    setUp(() {
      rasterService = _MockPdfRasterService();
      controller = PdfViewerController(
        rasterService: rasterService,
        pdfPath: pdfPath,
      );
    });

    test('loads pages successfully and updates state', () async {
      final page1 = Uint8List.fromList([1, 2, 3]);
      final page2 = Uint8List.fromList([4, 5, 6]);

      when(
        () => rasterService.rasterize(pdfPath: pdfPath, forceRefresh: false),
      ).thenAnswer((_) async => Result.ok([page1, page2]));

      await controller.load();

      expect(controller.isLoading.value, isFalse);
      expect(controller.failure.value, isNull);
      expect(controller.pages.length, 2);
      expect(controller.totalPages, 2);
      expect(controller.currentPage.value, 0);
      expect(controller.pageLabel(0), 'Page 1');
      verify(
        () => rasterService.rasterize(pdfPath: pdfPath, forceRefresh: false),
      ).called(1);
      verifyNever(() => rasterService.invalidate(any()));
    });

    test('sets failure and clears pages when rasterization fails', () async {
      when(() => rasterService.invalidate(pdfPath)).thenReturn(null);
      when(
        () => rasterService.rasterize(pdfPath: pdfPath, forceRefresh: true),
      ).thenAnswer(
        (_) async =>
            Result.error(const PdfFailure('Could not render PDF preview.')),
      );

      await controller.load(forceRefresh: true);

      expect(controller.isLoading.value, isFalse);
      expect(controller.pages, isEmpty);
      expect(controller.currentPage.value, 0);
      expect(controller.failure.value, isA<PdfFailure>());
      verify(() => rasterService.invalidate(pdfPath)).called(1);
      verify(
        () => rasterService.rasterize(pdfPath: pdfPath, forceRefresh: true),
      ).called(1);
    });
  });
}
