part of 'failures.dart';

final class FileFailure extends Failure {
  const FileFailure([super.message = 'File operation failed'])
      : super(code: 'FILE_ERROR');
}
