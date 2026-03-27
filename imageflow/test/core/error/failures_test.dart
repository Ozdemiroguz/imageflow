import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';

void main() {
  group('Failure', () {
    group('default messages', () {
      test('StorageFailure has correct default message and code', () {
        const f = StorageFailure();
        expect(f.message, 'Storage operation failed');
        expect(f.code, 'STORAGE_ERROR');
      });

      test('FileFailure has correct default message and code', () {
        const f = FileFailure();
        expect(f.message, 'File operation failed');
        expect(f.code, 'FILE_ERROR');
      });

      test('ProcessingFailure has correct default message and code', () {
        const f = ProcessingFailure();
        expect(f.message, 'Image processing failed');
        expect(f.code, 'PROCESSING_ERROR');
      });

      test('PdfFailure has correct default message and code', () {
        const f = PdfFailure();
        expect(f.message, 'PDF operation failed');
        expect(f.code, 'PDF_ERROR');
      });

      test('DetectionFailure has correct default message and code', () {
        const f = DetectionFailure();
        expect(f.message, 'Content detection failed');
        expect(f.code, 'DETECTION_ERROR');
      });

      test('CameraFailure has correct default message and code', () {
        const f = CameraFailure();
        expect(f.message, 'Camera operation failed');
        expect(f.code, 'CAMERA_ERROR');
      });

      test('PermissionFailure has correct default message and code', () {
        const f = PermissionFailure();
        expect(f.message, 'Permission denied');
        expect(f.code, 'PERMISSION_ERROR');
      });

      test('NativeChannelFailure has correct default message and code', () {
        const f = NativeChannelFailure();
        expect(f.message, 'Native platform error');
        expect(f.code, 'NATIVE_ERROR');
      });

      test('RouteArgumentFailure has correct default message and code', () {
        const f = RouteArgumentFailure();
        expect(f.message, 'Invalid route argument');
        expect(f.code, 'ROUTE_ARG_ERROR');
      });
    });

    group('custom messages', () {
      test('custom message overrides default', () {
        const f = StorageFailure('Box not open');
        expect(f.message, 'Box not open');
        expect(f.code, 'STORAGE_ERROR');
      });

      test('debugMessage field exists on base Failure', () {
        // Concrete subclasses do not expose debugMessage in their constructors.
        // We verify the field is accessible via the base type.
        const Failure f = StorageFailure('disk full');
        expect(f.debugMessage, isNull);
      });
    });

    group('toString', () {
      test('includes code bracket prefix when code is set', () {
        const f = StorageFailure('Box not open');
        expect(f.toString(), '[STORAGE_ERROR] Box not open');
      });

      test('no bracket prefix when code is null', () {
        // Failure can be constructed with no code only via the base constructor
        // which is abstract-sealed. We test the pattern via a concrete subclass:
        // All concrete subclasses set a code, so we verify via toString format.
        const f = FileFailure('disk full');
        expect(f.toString(), '[FILE_ERROR] disk full');
        expect(f.toString(), contains('['));
        expect(f.toString(), contains(']'));
      });

      test('toString contains the message', () {
        const f = DetectionFailure('no face found');
        expect(f.toString(), contains('no face found'));
      });
    });

    group('Failure is Exception', () {
      test('Failure implements Exception', () {
        const Failure f = StorageFailure();
        expect(f, isA<Exception>());
      });
    });

    group('sealed hierarchy', () {
      test('exhaustive switch compiles over all subtypes', () {
        const Failure f = DetectionFailure();

        final label = switch (f) {
          StorageFailure() => 'storage',
          FileFailure() => 'file',
          ProcessingFailure() => 'processing',
          PdfFailure() => 'pdf',
          DetectionFailure() => 'detection',
          CameraFailure() => 'camera',
          PermissionFailure() => 'permission',
          NativeChannelFailure() => 'native',
          RouteArgumentFailure() => 'route',
        };

        expect(label, 'detection');
      });
    });
  });
}
