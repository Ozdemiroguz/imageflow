part of 'result.dart';

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}
