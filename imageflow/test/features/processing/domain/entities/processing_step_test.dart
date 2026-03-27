import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/features/processing/domain/entities/processing_step.dart';

void main() {
  group('ProcessingStep', () {
    group('faceProgress', () {
      test('copying → 0.0', () {
        expect(ProcessingStep.copying.faceProgress, 0.0);
      });

      test('detectingFaces → 0.2', () {
        expect(ProcessingStep.detectingFaces.faceProgress, 0.2);
      });

      test('annotating → 0.5', () {
        expect(ProcessingStep.annotating.faceProgress, 0.5);
      });

      test('generatingThumbnail → 0.8', () {
        expect(ProcessingStep.generatingThumbnail.faceProgress, 0.8);
      });

      test('saving → 0.9', () {
        expect(ProcessingStep.saving.faceProgress, 0.9);
      });

      test('complete → 1.0', () {
        expect(ProcessingStep.complete.faceProgress, 1.0);
      });

      test('document-only steps return 0.0 in face flow', () {
        expect(ProcessingStep.detectingText.faceProgress, 0.0);
        expect(ProcessingStep.correctingPerspective.faceProgress, 0.0);
        expect(ProcessingStep.enhancingContrast.faceProgress, 0.0);
        expect(ProcessingStep.generatingPdf.faceProgress, 0.0);
      });

      test('face progress sequence is strictly increasing', () {
        final faceSteps = [
          ProcessingStep.copying,
          ProcessingStep.detectingFaces,
          ProcessingStep.annotating,
          ProcessingStep.generatingThumbnail,
          ProcessingStep.saving,
          ProcessingStep.complete,
        ];
        for (var i = 0; i < faceSteps.length - 1; i++) {
          expect(
            faceSteps[i].faceProgress,
            lessThan(faceSteps[i + 1].faceProgress),
          );
        }
      });
    });

    group('documentProgress', () {
      test('copying → 0.0', () {
        expect(ProcessingStep.copying.documentProgress, 0.0);
      });

      test('detectingText → 0.1', () {
        expect(ProcessingStep.detectingText.documentProgress, 0.1);
      });

      test('correctingPerspective → 0.3', () {
        expect(ProcessingStep.correctingPerspective.documentProgress, 0.3);
      });

      test('enhancingContrast → 0.5', () {
        expect(ProcessingStep.enhancingContrast.documentProgress, 0.5);
      });

      test('generatingPdf → 0.65', () {
        expect(ProcessingStep.generatingPdf.documentProgress, 0.65);
      });

      test('generatingThumbnail → 0.85', () {
        expect(ProcessingStep.generatingThumbnail.documentProgress, 0.85);
      });

      test('saving → 0.95', () {
        expect(ProcessingStep.saving.documentProgress, 0.95);
      });

      test('complete → 1.0', () {
        expect(ProcessingStep.complete.documentProgress, 1.0);
      });

      test('face-only step (detectingFaces) returns 0.0 in document flow', () {
        expect(ProcessingStep.detectingFaces.documentProgress, 0.0);
      });

      test('document progress sequence is strictly increasing', () {
        final docSteps = [
          ProcessingStep.copying,
          ProcessingStep.detectingText,
          ProcessingStep.correctingPerspective,
          ProcessingStep.enhancingContrast,
          ProcessingStep.generatingPdf,
          ProcessingStep.generatingThumbnail,
          ProcessingStep.saving,
          ProcessingStep.complete,
        ];
        for (var i = 0; i < docSteps.length - 1; i++) {
          expect(
            docSteps[i].documentProgress,
            lessThan(docSteps[i + 1].documentProgress),
          );
        }
      });
    });

    group('label', () {
      test('every step has a non-empty label', () {
        for (final step in ProcessingStep.values) {
          expect(step.label, isNotEmpty);
        }
      });

      test('complete step label is "Processing complete"', () {
        expect(ProcessingStep.complete.label, 'Processing complete');
      });
    });
  });
}
