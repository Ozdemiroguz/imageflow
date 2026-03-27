import '../../../core/error/failures.dart';
import '../../processing/domain/entities/processing_result.dart';
import '../../processing/domain/entities/processing_step.dart';
import '../presentation/models/batch_item_state.dart';
import '../presentation/models/batch_item_status.dart';

class BatchItemStateTransitions {
  const BatchItemStateTransitions();

  BatchItemState toPending(BatchItemState item, {String? imagePath}) {
    return item.copyWith(
      imagePath: imagePath ?? item.imagePath,
      status: BatchItemStatus.pending,
      step: null,
      errorMessage: null,
      errorCode: null,
      errorDetails: null,
      result: null,
    );
  }

  BatchItemState toRunning(BatchItemState item) {
    return item.copyWith(
      status: BatchItemStatus.running,
      step: ProcessingStep.copying,
      errorMessage: null,
      errorCode: null,
      errorDetails: null,
      result: null,
    );
  }

  BatchItemState withProgress(BatchItemState item, ProcessingStep step) {
    return item.copyWith(step: step);
  }

  BatchItemState toSuccess(BatchItemState item, ProcessingResult result) {
    return item.copyWith(
      status: BatchItemStatus.success,
      step: ProcessingStep.complete,
      errorMessage: null,
      errorCode: null,
      errorDetails: null,
      result: result,
    );
  }

  BatchItemState toFailure(BatchItemState item, Failure failure) {
    return item.copyWith(
      status: BatchItemStatus.failed,
      step: null,
      errorMessage: failure.message,
      errorCode: failure.code,
      errorDetails: failure.debugMessage,
      result: null,
    );
  }
}
