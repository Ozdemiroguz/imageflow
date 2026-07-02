import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:imageflow/core/enums/processing_type.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/features/batch/presentation/models/batch_item_state.dart';
import 'package:imageflow/features/batch/presentation/models/batch_item_status.dart';
import 'package:imageflow/features/processing/domain/entities/processing_result.dart';
import 'package:imageflow/features/processing/domain/entities/processing_step.dart';
import 'package:imageflow/features/batch/presentation/services/batch_item_state_manager.dart';

ProcessingResult _result() => ProcessingResult(
  id: 'r',
  type: ProcessingType.document,
  originalImagePath: '/o.jpg',
  processedImagePath: '/p.jpg',
  thumbnailPath: '/t.jpg',
  fileSizeBytes: 1,
  createdAt: DateTime(2026),
  extractedText: '',
  facesDetected: 0,
  faceRects: const [],
  faceContours: const [],
);

void main() {
  const manager = BatchItemStateManager();

  RxList<BatchItemState> queueOf(BatchItemStatus status) => <BatchItemState>[
    BatchItemState(index: 0, imagePath: 'a.jpg', status: status),
  ].obs;

  test('toRunning sets running + copying step', () {
    final items = queueOf(BatchItemStatus.pending);
    manager.toRunning(items, 0);
    expect(items[0].status, BatchItemStatus.running);
    expect(items[0].step, ProcessingStep.copying);
  });

  test('toSuccess sets success + complete step + result', () {
    final items = queueOf(BatchItemStatus.running);
    final result = _result();
    manager.toSuccess(items, 0, result);
    expect(items[0].status, BatchItemStatus.success);
    expect(items[0].step, ProcessingStep.complete);
    expect(items[0].result, same(result));
  });

  test('toFailure records the failure message and clears result', () {
    final items = queueOf(BatchItemStatus.running);
    manager.toFailure(items, 0, const ProcessingFailure('oops'));
    expect(items[0].status, BatchItemStatus.failed);
    expect(items[0].errorMessage, 'oops');
    expect(items[0].result, isNull);
  });

  test('toPending clears prior error + result and can swap the path', () {
    final items = <BatchItemState>[
      const BatchItemState(
        index: 0,
        imagePath: 'old.jpg',
        status: BatchItemStatus.failed,
        errorMessage: 'x',
        errorCode: 'y',
      ),
    ].obs;

    manager.toPending(items, 0, imagePath: 'new.jpg');

    expect(items[0].status, BatchItemStatus.pending);
    expect(items[0].imagePath, 'new.jpg');
    expect(items[0].errorMessage, isNull);
    expect(items[0].errorCode, isNull);
  });

  test('out-of-range index is a no-op', () {
    final items = queueOf(BatchItemStatus.pending);
    final before = items[0];
    manager.toRunning(items, 5);
    manager.toRunning(items, -1);
    expect(items[0], same(before));
  });

  test('applying an identical transition does not replace the object '
      '(dedupe avoids spurious rebuilds)', () {
    final items = queueOf(BatchItemStatus.running);
    // Seed with the copying step so toRunning would produce an equal state.
    manager.toRunning(items, 0);
    final afterFirst = items[0];

    manager.toRunning(items, 0); // same target state
    expect(items[0], same(afterFirst), reason: 'object should be reused');
  });

  test('withProgress only updates the step', () {
    final items = queueOf(BatchItemStatus.running);
    manager.withProgress(items, 0, ProcessingStep.generatingPdf);
    expect(items[0].step, ProcessingStep.generatingPdf);
    expect(items[0].status, BatchItemStatus.running);
  });
}
