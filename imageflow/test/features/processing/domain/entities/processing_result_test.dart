import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';

void main() {
  group('ProcessingResult', () {
    group('default values', () {
      test('facesDetected defaults to 0', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.face,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 512,
          createdAt: DateTime(2024),
        );
        expect(r.facesDetected, 0);
      });

      test('faceRects defaults to empty list', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.face,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 512,
          createdAt: DateTime(2024),
        );
        expect(r.faceRects, isEmpty);
      });

      test('faceContours defaults to empty list', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.face,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 512,
          createdAt: DateTime(2024),
        );
        expect(r.faceContours, isEmpty);
      });

      test('extractedText defaults to null', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.document,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 512,
          createdAt: DateTime(2024),
        );
        expect(r.extractedText, isNull);
      });

      test('pdfPath defaults to null', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.document,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 512,
          createdAt: DateTime(2024),
        );
        expect(r.pdfPath, isNull);
      });
    });

    group('face result', () {
      test('stores all face-specific fields', () {
        final rects = [(left: 10, top: 20, width: 100, height: 120)];
        final contours = [[(x: 1, y: 2), (x: 3, y: 4)]];
        final createdAt = DateTime(2024, 3, 10);

        final r = ProcessingResult(
          id: 'face-1',
          type: ProcessingType.face,
          originalImagePath: '/originals/face-1.jpg',
          processedImagePath: '/processed/face-1.jpg',
          thumbnailPath: '/thumbs/face-1.jpg',
          fileSizeBytes: 204800,
          createdAt: createdAt,
          facesDetected: 3,
          faceRects: rects,
          faceContours: contours,
        );

        expect(r.id, 'face-1');
        expect(r.type, ProcessingType.face);
        expect(r.facesDetected, 3);
        expect(r.faceRects, hasLength(1));
        expect(r.faceRects.first.left, 10);
        expect(r.faceContours, hasLength(1));
        expect(r.faceContours.first.first.x, 1);
        expect(r.createdAt, createdAt);
        expect(r.pdfPath, isNull);
        expect(r.extractedText, isNull);
      });
    });

    group('document result', () {
      test('stores all document-specific fields', () {
        final r = ProcessingResult(
          id: 'doc-1',
          type: ProcessingType.document,
          originalImagePath: '/originals/doc-1.jpg',
          processedImagePath: '/processed/doc-1.jpg',
          thumbnailPath: '/thumbs/doc-1.jpg',
          fileSizeBytes: 51200,
          createdAt: DateTime(2024, 5, 1),
          extractedText: 'Invoice #001',
          pdfPath: '/pdfs/doc-1.pdf',
        );

        expect(r.id, 'doc-1');
        expect(r.type, ProcessingType.document);
        expect(r.extractedText, 'Invoice #001');
        expect(r.pdfPath, '/pdfs/doc-1.pdf');
        expect(r.facesDetected, 0);
        expect(r.faceRects, isEmpty);
        expect(r.faceContours, isEmpty);
      });
    });

    group('required fields', () {
      test('thumbnailPath is required and stored correctly', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.face,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/thumbs/id.jpg',
          fileSizeBytes: 1024,
          createdAt: DateTime(2024),
        );
        expect(r.thumbnailPath, '/thumbs/id.jpg');
      });

      test('fileSizeBytes is stored correctly', () {
        final r = ProcessingResult(
          id: 'id',
          type: ProcessingType.face,
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          thumbnailPath: '/t.jpg',
          fileSizeBytes: 999999,
          createdAt: DateTime(2024),
        );
        expect(r.fileSizeBytes, 999999);
      });
    });
  });
}
