part of 'failures.dart';

final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied'])
      : super(code: 'PERMISSION_ERROR');
}
