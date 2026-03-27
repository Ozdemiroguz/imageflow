part of 'result.dart';

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
