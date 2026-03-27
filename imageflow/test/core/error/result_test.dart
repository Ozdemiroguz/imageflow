import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';

void main() {
  group('Result', () {
    group('factories', () {
      test('Result.ok creates Ok<T> with value', () {
        final result = Result.ok(42);

        expect(result, isA<Ok<int>>());
        expect((result as Ok<int>).value, 42);
      });

      test('Result.error creates Error<T> with failure', () {
        const failure = StorageFailure();
        final result = Result<int>.error(failure);

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).failure, same(failure));
      });

      test('Result.ok works with null value (void-like)', () {
        final result = Result.ok(null);
        expect(result, isA<Ok<Null>>());
      });

      test('Result.ok works with complex types', () {
        final result = Result.ok(['a', 'b', 'c']);
        expect(result, isA<Ok<List<String>>>());
        expect((result as Ok<List<String>>).value, ['a', 'b', 'c']);
      });
    });

    group('isOk / isError', () {
      test('isOk is true for Ok', () {
        expect(Result.ok(1).isOk, isTrue);
      });

      test('isOk is false for Error', () {
        expect(Result<int>.error(const StorageFailure()).isOk, isFalse);
      });

      test('isError is true for Error', () {
        expect(Result<int>.error(const StorageFailure()).isError, isTrue);
      });

      test('isError is false for Ok', () {
        expect(Result.ok(1).isError, isFalse);
      });
    });

    group('guard', () {
      test('returns Ok when action succeeds', () async {
        final result = await Result.guard(
          () async => 'success',
          onError: (_) => const ProcessingFailure(),
        );

        expect(result.isOk, isTrue);
        expect((result as Ok<String>).value, 'success');
      });

      test('returns Error mapped by onError when action throws', () async {
        final result = await Result.guard<String>(
          () async => throw Exception('boom'),
          onError: (e) => ProcessingFailure(e.toString()),
        );

        expect(result.isError, isTrue);
        expect((result as Error<String>).failure, isA<ProcessingFailure>());
      });

      test('calls onLog with error and stacktrace when action throws', () async {
        Object? capturedError;
        StackTrace? capturedStack;

        await Result.guard<void>(
          () async => throw StateError('test error'),
          onError: (_) => const ProcessingFailure(),
          onLog: (e, st) {
            capturedError = e;
            capturedStack = st;
          },
        );

        expect(capturedError, isA<StateError>());
        expect(capturedStack, isNotNull);
      });

      test('does not call onLog on success', () async {
        var logCalled = false;

        await Result.guard(
          () async => 42,
          onError: (_) => const ProcessingFailure(),
          onLog: (_, _) => logCalled = true,
        );

        expect(logCalled, isFalse);
      });

      test('catches non-Exception errors (e.g. Error subclasses)', () async {
        final result = await Result.guard<void>(
          () async => throw AssertionError('assert failed'),
          onError: (e) => ProcessingFailure(e.toString()),
        );

        expect(result.isError, isTrue);
      });

      test('onError receives the thrown object', () async {
        Object? received;

        await Result.guard<void>(
          () async => throw const FileFailure('custom'),
          onError: (e) {
            received = e;
            return const ProcessingFailure();
          },
        );

        expect(received, isA<FileFailure>());
      });
    });

    group('exhaustive switch', () {
      test('sealed class forces exhaustive switch at compile time', () {
        final Result<int> result = Result.ok(1);

        // This test validates that the switch below compiles without a default case.
        final label = switch (result) {
          Ok(:final value) => 'ok:$value',
          Error(:final failure) => 'error:${failure.message}',
        };

        expect(label, 'ok:1');
      });
    });
  });
}
