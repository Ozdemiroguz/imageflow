part of 'failures.dart';

final class DetectionFailure extends Failure {
  const DetectionFailure([super.message = 'Content detection failed'])
      : super(code: 'DETECTION_ERROR');
}
