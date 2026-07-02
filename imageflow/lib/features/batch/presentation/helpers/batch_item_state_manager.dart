import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../processing/domain/entities/processing_result.dart';
import '../../../processing/domain/entities/processing_step.dart';
import '../models/batch_item_state.dart';
import '../models/batch_item_status.dart';

/// Owns batch-item state changes: computes the next [BatchItemState] for a
/// transition and applies it to the reactive [RxList] in one step.
///
/// Merges the former `BatchItemStateTransitions` (compute) and
/// `BatchItemStateMutator` (apply) — every caller used them together
/// (compute-then-apply), so they are one responsibility.
class BatchItemStateManager {
  const BatchItemStateManager();

  void toPending(RxList<BatchItemState> items, int index, {String? imagePath}) {
    _apply(
      items,
      index,
      (item) => item.copyWith(
        imagePath: imagePath ?? item.imagePath,
        status: BatchItemStatus.pending,
        step: null,
        errorMessage: null,
        errorCode: null,
        errorDetails: null,
        result: null,
      ),
    );
  }

  void toRunning(RxList<BatchItemState> items, int index) {
    _apply(
      items,
      index,
      (item) => item.copyWith(
        status: BatchItemStatus.running,
        step: ProcessingStep.copying,
        errorMessage: null,
        errorCode: null,
        errorDetails: null,
        result: null,
      ),
    );
  }

  void withProgress(
    RxList<BatchItemState> items,
    int index,
    ProcessingStep step,
  ) {
    _apply(items, index, (item) => item.copyWith(step: step));
  }

  void toSuccess(
    RxList<BatchItemState> items,
    int index,
    ProcessingResult result,
  ) {
    _apply(
      items,
      index,
      (item) => item.copyWith(
        status: BatchItemStatus.success,
        step: ProcessingStep.complete,
        errorMessage: null,
        errorCode: null,
        errorDetails: null,
        result: result,
      ),
    );
  }

  void toFailure(RxList<BatchItemState> items, int index, Failure failure) {
    _apply(
      items,
      index,
      (item) => item.copyWith(
        status: BatchItemStatus.failed,
        step: null,
        errorMessage: failure.message,
        errorCode: failure.code,
        errorDetails: failure.debugMessage,
        result: null,
      ),
    );
  }

  /// Computes the next state from the current item and writes it back only if
  /// it actually changed (avoids spurious reactive rebuilds).
  void _apply(
    RxList<BatchItemState> items,
    int index,
    BatchItemState Function(BatchItemState current) transition,
  ) {
    if (index < 0 || index >= items.length) return;
    final current = items[index];
    final next = transition(current);
    if (_isSame(current, next)) return;
    items[index] = next;
  }

  bool _isSame(BatchItemState a, BatchItemState b) {
    return a.index == b.index &&
        a.imagePath == b.imagePath &&
        a.status == b.status &&
        a.step == b.step &&
        a.errorMessage == b.errorMessage &&
        a.errorCode == b.errorCode &&
        a.errorDetails == b.errorDetails &&
        identical(a.result, b.result);
  }
}
