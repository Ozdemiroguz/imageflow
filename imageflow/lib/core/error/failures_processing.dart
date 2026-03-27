part of 'failures.dart';

final class ProcessingFailure extends Failure {
  const ProcessingFailure([super.message = 'Image processing failed'])
      : super(code: 'PROCESSING_ERROR');
}
