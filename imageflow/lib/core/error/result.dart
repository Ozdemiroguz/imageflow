import 'failures.dart';

part 'result_ok.dart';
part 'result_error.dart';

sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.error(Failure failure) = Error<T>;

  bool get isOk => this is Ok<T>;
  bool get isError => this is Error<T>;

  /// Wraps [action] in try-catch, returning Ok on success or Error with
  /// [onError] failure on exception.
  static Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    required Failure Function(Object error) onError,
    void Function(Object error, StackTrace stackTrace)? onLog,
  }) async {
    try {
      return Result.ok(await action());
    } catch (e, st) {
      onLog?.call(e, st);
      return Result.error(onError(e));
    }
  }
}
