import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';

void main() {
  group('ProcessingHistory', () {
    group('default values', () {
      test('facesDetected defaults to 0', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.facesDetected, 0);
      });

      test('faceRects defaults to empty list', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.faceRects, isEmpty);
      });

      test('faceContours defaults to empty list', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.faceContours, isEmpty);
      });

      test('optional fields default to null', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.thumbnailPath, isNull);
        expect(h.pdfPath, isNull);
        expect(h.extractedText, isNull);
      });
    });

    group('fields', () {
      test('stores all required fields correctly', () {
        final createdAt = DateTime(2024, 6, 15);
        final h = ProcessingHistory(
          id: 'abc-123',
          originalImagePath: '/originals/abc.jpg',
          processedImagePath: '/processed/abc.jpg',
          type: ProcessingType.document,
          createdAt: createdAt,
          fileSizeBytes: 204800,
          thumbnailPath: '/thumbs/abc.jpg',
          pdfPath: '/pdfs/abc.pdf',
          extractedText: 'Hello World',
          facesDetected: 2,
        );

        expect(h.id, 'abc-123');
        expect(h.originalImagePath, '/originals/abc.jpg');
        expect(h.processedImagePath, '/processed/abc.jpg');
        expect(h.type, ProcessingType.document);
        expect(h.createdAt, createdAt);
        expect(h.fileSizeBytes, 204800);
        expect(h.thumbnailPath, '/thumbs/abc.jpg');
        expect(h.pdfPath, '/pdfs/abc.pdf');
        expect(h.extractedText, 'Hello World');
        expect(h.facesDetected, 2);
      });

      test('stores faceRects correctly', () {
        final rects = [
          (left: 10, top: 20, width: 100, height: 120),
          (left: 200, top: 50, width: 80, height: 90),
        ];
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
          faceRects: rects,
        );

        expect(h.faceRects, hasLength(2));
        expect(h.faceRects.first.left, 10);
        expect(h.faceRects.first.top, 20);
        expect(h.faceRects.first.width, 100);
        expect(h.faceRects.first.height, 120);
      });

      test('stores faceContours correctly', () {
        final contours = [
          [(x: 1, y: 2), (x: 3, y: 4)],
          [(x: 5, y: 6)],
        ];
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
          faceContours: contours,
        );

        expect(h.faceContours, hasLength(2));
        expect(h.faceContours.first.first.x, 1);
        expect(h.faceContours.first.first.y, 2);
      });
    });

    group('ProcessingType enum', () {
      test('face type is correctly set', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.type, ProcessingType.face);
      });

      test('document type is correctly set', () {
        final h = ProcessingHistory(
          id: 'id',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.document,
          createdAt: DateTime(2024),
          fileSizeBytes: 512,
        );
        expect(h.type, ProcessingType.document);
      });
    });
  });
}
