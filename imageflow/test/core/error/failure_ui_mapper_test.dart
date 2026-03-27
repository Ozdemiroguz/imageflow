import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/enums/notification_type.dart';
import 'package:imageflow/core/error/failure_ui_mapper.dart';
import 'package:imageflow/core/error/failures.dart';

void main() {
  group('FailureUiMapper', () {
    group('type mapping', () {
      test('DetectionFailure → info type', () {
        final ui = FailureUiMapper.map(const DetectionFailure());
        expect(ui.type, NotificationType.info);
      });

      test('ProcessingFailure → error type', () {
        final ui = FailureUiMapper.map(const ProcessingFailure());
        expect(ui.type, NotificationType.error);
      });

      test('PdfFailure → error type', () {
        final ui = FailureUiMapper.map(const PdfFailure());
        expect(ui.type, NotificationType.error);
      });

      test('PermissionFailure → warning type', () {
        final ui = FailureUiMapper.map(const PermissionFailure());
        expect(ui.type, NotificationType.warning);
      });

      test('CameraFailure → error type', () {
        final ui = FailureUiMapper.map(const CameraFailure());
        expect(ui.type, NotificationType.error);
      });

      test('FileFailure → error type', () {
        final ui = FailureUiMapper.map(const FileFailure());
        expect(ui.type, NotificationType.error);
      });

      test('StorageFailure → error type', () {
        final ui = FailureUiMapper.map(const StorageFailure());
        expect(ui.type, NotificationType.error);
      });

      test('NativeChannelFailure → error type', () {
        final ui = FailureUiMapper.map(const NativeChannelFailure());
        expect(ui.type, NotificationType.error);
      });

      test('RouteArgumentFailure → error type', () {
        final ui = FailureUiMapper.map(const RouteArgumentFailure());
        expect(ui.type, NotificationType.error);
      });
    });

    group('canRetry flag', () {
      test('DetectionFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const DetectionFailure()).canRetry, isTrue);
      });

      test('ProcessingFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const ProcessingFailure()).canRetry, isTrue);
      });

      test('PdfFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const PdfFailure()).canRetry, isTrue);
      });

      test('CameraFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const CameraFailure()).canRetry, isTrue);
      });

      test('FileFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const FileFailure()).canRetry, isTrue);
      });

      test('StorageFailure → canRetry: true', () {
        expect(FailureUiMapper.map(const StorageFailure()).canRetry, isTrue);
      });

      test('NativeChannelFailure → canRetry: true', () {
        expect(
          FailureUiMapper.map(const NativeChannelFailure()).canRetry,
          isTrue,
        );
      });

      test('PermissionFailure → canRetry: false', () {
        expect(
          FailureUiMapper.map(const PermissionFailure()).canRetry,
          isFalse,
        );
      });

      test('RouteArgumentFailure → canRetry: false', () {
        expect(
          FailureUiMapper.map(const RouteArgumentFailure()).canRetry,
          isFalse,
        );
      });
    });

    group('titles', () {
      test('DetectionFailure → "Nothing Detected"', () {
        expect(FailureUiMapper.map(const DetectionFailure()).title,
            'Nothing Detected');
      });

      test('ProcessingFailure → "Processing Failed"', () {
        expect(FailureUiMapper.map(const ProcessingFailure()).title,
            'Processing Failed');
      });

      test('PdfFailure → "PDF Error"', () {
        expect(FailureUiMapper.map(const PdfFailure()).title, 'PDF Error');
      });

      test('PermissionFailure → "Permission Required"', () {
        expect(FailureUiMapper.map(const PermissionFailure()).title,
            'Permission Required');
      });

      test('CameraFailure → "Camera Error"', () {
        expect(
            FailureUiMapper.map(const CameraFailure()).title, 'Camera Error');
      });

      test('FileFailure → "Storage Error"', () {
        expect(FailureUiMapper.map(const FileFailure()).title, 'Storage Error');
      });

      test('StorageFailure → "Storage Error"', () {
        expect(
            FailureUiMapper.map(const StorageFailure()).title, 'Storage Error');
      });

      test('NativeChannelFailure → "Platform Error"', () {
        expect(FailureUiMapper.map(const NativeChannelFailure()).title,
            'Platform Error');
      });

      test('RouteArgumentFailure → "Navigation Error"', () {
        expect(FailureUiMapper.map(const RouteArgumentFailure()).title,
            'Navigation Error');
      });
    });

    group('message passthrough', () {
      test('custom failure message is passed through to UiError.message', () {
        const f = DetectionFailure('No face in this photo');
        final ui = FailureUiMapper.map(f);
        expect(ui.message, 'No face in this photo');
      });

      test('default failure message is passed through', () {
        final ui = FailureUiMapper.map(const StorageFailure());
        expect(ui.message, 'Storage operation failed');
      });
    });
  });
}
