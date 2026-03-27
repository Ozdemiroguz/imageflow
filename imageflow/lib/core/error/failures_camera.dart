part of 'failures.dart';

final class CameraFailure extends Failure {
  const CameraFailure([super.message = 'Camera operation failed'])
      : super(code: 'CAMERA_ERROR');
}
