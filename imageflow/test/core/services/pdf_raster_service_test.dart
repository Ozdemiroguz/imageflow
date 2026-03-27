import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/core/services/pdf_raster/pdf_raster_service.dart';

void main() {
  group('PdfRasterService', () {
    late Directory tempDir;
    late String pdfPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_raster_service_test_');
      final file = File('${tempDir.path}/sample.pdf');
      await file.writeAsBytes(const [1, 2, 3, 4, 5]);
      pdfPath = file.path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('uses cache and avoids repeated rasterization for same file', () async {
      var rasterCalls = 0;
      final pageA = Uint8List.fromList([10, 20, 30]);
      final pageB = Uint8List.fromList([40, 50, 60]);

      final service = PdfRasterService(
        rasterizer: (bytes, dpi) async {
          rasterCalls++;
          return [pageA, pageB];
        },
      );

      final first = await service.rasterize(pdfPath: pdfPath);
      final second = await service.rasterize(pdfPath: pdfPath);

      expect(rasterCalls, 1);
      expect(_okValue(first).length, 2);
      expect(_okValue(second).length, 2);
      expect(_okValue(second)[0], same(_okValue(first)[0]));
    });

    test('dedupes concurrent rasterization requests for same file', () async {
      var rasterCalls = 0;
      final completer = Completer<List<Uint8List>>();
      final page = Uint8List.fromList([7, 8, 9]);

      final service = PdfRasterService(
        rasterizer: (bytes, dpi) async {
          rasterCalls++;
          return completer.future;
        },
      );

      final futureA = service.rasterize(pdfPath: pdfPath);
      final futureB = service.rasterize(pdfPath: pdfPath);

      for (var i = 0; i < 20 && rasterCalls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(rasterCalls, 1);

      completer.complete([page]);
      final resultA = await futureA;
      final resultB = await futureB;

      expect(_okValue(resultA).length, 1);
      expect(_okValue(resultB).length, 1);
      expect(_okValue(resultA).first, same(_okValue(resultB).first));
      expect(rasterCalls, 1);
    });
  });
}

List<Uint8List> _okValue(Result<List<Uint8List>> result) => switch (result) {
      Ok(:final value) => value,
      Error(:final failure) => throw StateError('Expected Ok, got ${failure.message}'),
    };
