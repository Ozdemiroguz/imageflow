import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/features/history/data/models/processing_history_model.dart';
import 'package:imageflow/features/history/domain/entities/processing_history.dart';

ProcessingHistory _faceHistory() => ProcessingHistory(
      id: 'face-id',
      originalImagePath: '/originals/face.jpg',
      processedImagePath: '/processed/face.jpg',
      type: ProcessingType.face,
      createdAt: DateTime(2024, 6, 15),
      fileSizeBytes: 4096,
      thumbnailPath: '/thumbnails/face_thumb.jpg',
      facesDetected: 2,
      faceRects: [
        (left: 10, top: 20, width: 100, height: 120),
        (left: 200, top: 50, width: 80, height: 90),
      ],
      faceContours: [
        [(x: 10, y: 20), (x: 30, y: 40)],
        [(x: 200, y: 50), (x: 220, y: 70)],
      ],
    );

ProcessingHistory _documentHistory() => ProcessingHistory(
      id: 'doc-id',
      originalImagePath: '/originals/doc.jpg',
      processedImagePath: '/processed/doc.jpg',
      type: ProcessingType.document,
      createdAt: DateTime(2024, 1, 1),
      fileSizeBytes: 8192,
      pdfPath: '/pdfs/doc.pdf',
      extractedText: 'Hello World',
    );

void main() {
  group('ProcessingHistoryModel', () {
    group('fromEntity — face', () {
      test('maps all scalar fields correctly', () {
        final entity = _faceHistory();
        final model = ProcessingHistoryModel.fromEntity(entity);

        expect(model.id, entity.id);
        expect(model.originalImagePath, entity.originalImagePath);
        expect(model.processedImagePath, entity.processedImagePath);
        expect(model.createdAt, entity.createdAt);
        expect(model.fileSizeBytes, entity.fileSizeBytes);
        expect(model.thumbnailPath, entity.thumbnailPath);
        expect(model.facesDetected, entity.facesDetected);
      });

      test('maps ProcessingType.face → ProcessingTypeModel.face', () {
        final model = ProcessingHistoryModel.fromEntity(_faceHistory());
        expect(model.type, ProcessingTypeModel.face);
      });

      test('serializes faceRects as [left, top, width, height] lists', () {
        final model = ProcessingHistoryModel.fromEntity(_faceHistory());

        expect(model.faceRects.length, 2);
        expect(model.faceRects[0], [10, 20, 100, 120]);
        expect(model.faceRects[1], [200, 50, 80, 90]);
      });

      test('serializes faceContours as [[x, y]] nested lists', () {
        final model = ProcessingHistoryModel.fromEntity(_faceHistory());

        expect(model.faceContours.length, 2);
        expect(model.faceContours[0], [[10, 20], [30, 40]]);
        expect(model.faceContours[1], [[200, 50], [220, 70]]);
      });

      test('pdfPath and extractedText are null for face entity', () {
        final model = ProcessingHistoryModel.fromEntity(_faceHistory());
        expect(model.pdfPath, isNull);
        expect(model.extractedText, isNull);
      });
    });

    group('fromEntity — document', () {
      test('maps ProcessingType.document → ProcessingTypeModel.document', () {
        final model = ProcessingHistoryModel.fromEntity(_documentHistory());
        expect(model.type, ProcessingTypeModel.document);
      });

      test('maps pdfPath and extractedText', () {
        final model = ProcessingHistoryModel.fromEntity(_documentHistory());
        expect(model.pdfPath, '/pdfs/doc.pdf');
        expect(model.extractedText, 'Hello World');
      });

      test('faceRects and faceContours are empty for document entity', () {
        final model = ProcessingHistoryModel.fromEntity(_documentHistory());
        expect(model.faceRects, isEmpty);
        expect(model.faceContours, isEmpty);
      });

      test('thumbnailPath is null when not provided', () {
        final model = ProcessingHistoryModel.fromEntity(_documentHistory());
        expect(model.thumbnailPath, isNull);
      });
    });

    group('toEntity — face', () {
      test('reconstructs all scalar fields', () {
        final original = _faceHistory();
        final entity = ProcessingHistoryModel.fromEntity(original).toEntity();

        expect(entity.id, original.id);
        expect(entity.originalImagePath, original.originalImagePath);
        expect(entity.processedImagePath, original.processedImagePath);
        expect(entity.createdAt, original.createdAt);
        expect(entity.fileSizeBytes, original.fileSizeBytes);
        expect(entity.thumbnailPath, original.thumbnailPath);
        expect(entity.facesDetected, original.facesDetected);
        expect(entity.type, ProcessingType.face);
      });

      test('reconstructs faceRects as named records', () {
        final entity =
            ProcessingHistoryModel.fromEntity(_faceHistory()).toEntity();

        expect(entity.faceRects.length, 2);
        expect(entity.faceRects[0].left, 10);
        expect(entity.faceRects[0].top, 20);
        expect(entity.faceRects[0].width, 100);
        expect(entity.faceRects[0].height, 120);
      });

      test('reconstructs faceContours as named records', () {
        final entity =
            ProcessingHistoryModel.fromEntity(_faceHistory()).toEntity();

        expect(entity.faceContours.length, 2);
        expect(entity.faceContours[0][0].x, 10);
        expect(entity.faceContours[0][0].y, 20);
        expect(entity.faceContours[0][1].x, 30);
        expect(entity.faceContours[0][1].y, 40);
      });
    });

    group('toEntity — document', () {
      test('maps ProcessingTypeModel.document → ProcessingType.document', () {
        final entity =
            ProcessingHistoryModel.fromEntity(_documentHistory()).toEntity();
        expect(entity.type, ProcessingType.document);
      });

      test('preserves pdfPath and extractedText', () {
        final entity =
            ProcessingHistoryModel.fromEntity(_documentHistory()).toEntity();
        expect(entity.pdfPath, '/pdfs/doc.pdf');
        expect(entity.extractedText, 'Hello World');
      });
    });

    group('round-trip', () {
      test('face entity survives entity → model → entity round-trip', () {
        final original = _faceHistory();
        final restored =
            ProcessingHistoryModel.fromEntity(original).toEntity();

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.fileSizeBytes, original.fileSizeBytes);
        expect(restored.facesDetected, original.facesDetected);
        expect(restored.faceRects.length, original.faceRects.length);
        expect(restored.faceContours.length, original.faceContours.length);
      });

      test('document entity survives round-trip', () {
        final original = _documentHistory();
        final restored =
            ProcessingHistoryModel.fromEntity(original).toEntity();

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.pdfPath, original.pdfPath);
        expect(restored.extractedText, original.extractedText);
        expect(restored.faceRects, isEmpty);
        expect(restored.faceContours, isEmpty);
      });

      test('entity with no optional fields survives round-trip', () {
        final minimal = ProcessingHistory(
          id: 'min',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingType.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 100,
        );
        final restored =
            ProcessingHistoryModel.fromEntity(minimal).toEntity();

        expect(restored.thumbnailPath, isNull);
        expect(restored.pdfPath, isNull);
        expect(restored.extractedText, isNull);
        expect(restored.faceRects, isEmpty);
        expect(restored.faceContours, isEmpty);
        expect(restored.facesDetected, 0);
      });
    });

    group('toEntity — malformed faceRects filtering', () {
      test('filters out faceRect entries with wrong length', () {
        final model = ProcessingHistoryModel(
          id: 'test',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingTypeModel.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 100,
          // One valid [4 ints], one invalid [3 ints]
          faceRects: [
            [10, 20, 100, 120],
            [1, 2, 3], // malformed — should be filtered
          ],
        );

        final entity = model.toEntity();
        expect(entity.faceRects.length, 1);
        expect(entity.faceRects[0].left, 10);
      });

      test('filters out contour points with wrong length', () {
        final model = ProcessingHistoryModel(
          id: 'test',
          originalImagePath: '/o.jpg',
          processedImagePath: '/p.jpg',
          type: ProcessingTypeModel.face,
          createdAt: DateTime(2024),
          fileSizeBytes: 100,
          faceContours: [
            [
              [10, 20], // valid
              [5], // malformed — should be filtered
            ],
          ],
        );

        final entity = model.toEntity();
        expect(entity.faceContours[0].length, 1);
        expect(entity.faceContours[0][0].x, 10);
      });
    });
  });
}
