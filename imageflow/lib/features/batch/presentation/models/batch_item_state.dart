import '../../../processing/domain/entities/processing_result.dart';
import '../../../processing/domain/entities/processing_step.dart';
import 'batch_item_status.dart';

class BatchItemState {
  const BatchItemState({
    required this.index,
    required this.imagePath,
    required this.status,
    this.step,
    this.errorMessage,
    this.errorCode,
    this.errorDetails,
    this.result,
  });

  final int index;
  final String imagePath;
  final BatchItemStatus status;
  final ProcessingStep? step;
  final String? errorMessage;
  final String? errorCode;
  final String? errorDetails;
  final ProcessingResult? result;

  static const _unset = Object();

  BatchItemState copyWith({
    String? imagePath,
    BatchItemStatus? status,
    Object? step = _unset,
    Object? errorMessage = _unset,
    Object? errorCode = _unset,
    Object? errorDetails = _unset,
    Object? result = _unset,
  }) {
    return BatchItemState(
      index: index,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      step: identical(step, _unset) ? this.step : step as ProcessingStep?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      errorCode: identical(errorCode, _unset)
          ? this.errorCode
          : errorCode as String?,
      errorDetails: identical(errorDetails, _unset)
          ? this.errorDetails
          : errorDetails as String?,
      result: identical(result, _unset)
          ? this.result
          : result as ProcessingResult?,
    );
  }
}
