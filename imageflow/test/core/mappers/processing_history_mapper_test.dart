import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/mappers/processing_history_mapper.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';

void main() {
  group('ProcessingHistoryMapper.resultFromHistory', () {
    ProcessingHistory buildHistory({String? thumbnailPath, String? pdfPath}) {
      return ProcessingHistory(
        id: 'h1',
        type: ProcessingType.document,
        originalImagePath: '/abs/orig.jpg',
        processedImagePath: '/abs/proc.jpg',
        thumbnailPath: thumbnailPath,
        pdfPath: pdfPath,
        fileSizeBytes: 1234,
        createdAt: DateTime(2026, 1, 1),
        extractedText: 'hello',
        facesDetected: 0,
        faceRects: const [],
        faceContours: const [],
      );
    }

    test('carries absolute paths and fields over unchanged', () {
      final result = ProcessingHistoryMapper.resultFromHistory(
        buildHistory(thumbnailPath: '/abs/thumb.jpg', pdfPath: '/abs/doc.pdf'),
      );

      expect(result.id, 'h1');
      expect(result.type, ProcessingType.document);
      expect(result.originalImagePath, '/abs/orig.jpg');
      expect(result.processedImagePath, '/abs/proc.jpg');
      expect(result.thumbnailPath, '/abs/thumb.jpg');
      expect(result.pdfPath, '/abs/doc.pdf');
      expect(result.fileSizeBytes, 1234);
      expect(result.createdAt, DateTime(2026, 1, 1));
      expect(result.extractedText, 'hello');
    });

    test('legacy record with null thumbnail maps to empty path', () {
      final result = ProcessingHistoryMapper.resultFromHistory(
        buildHistory(thumbnailPath: null),
      );

      expect(result.thumbnailPath, '');
    });

    test('null pdf stays null', () {
      final result = ProcessingHistoryMapper.resultFromHistory(
        buildHistory(pdfPath: null),
      );

      expect(result.pdfPath, isNull);
    });
  });
}
