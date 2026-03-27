part of 'failures.dart';

final class NativeChannelFailure extends Failure {
  const NativeChannelFailure([super.message = 'Native platform error'])
      : super(code: 'NATIVE_ERROR');
}
