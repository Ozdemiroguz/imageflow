part of 'failures.dart';

final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage operation failed'])
      : super(code: 'STORAGE_ERROR');
}
