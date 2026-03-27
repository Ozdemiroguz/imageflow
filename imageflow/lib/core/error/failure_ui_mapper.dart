import '../enums/notification_type.dart';
import 'failures.dart';

part 'failure_ui_mapper_ui_error.dart';

abstract final class FailureUiMapper {
  static UiError map(Failure failure) => switch (failure) {
        DetectionFailure() => (
            title: 'Nothing Detected',
            message: failure.message,
            type: NotificationType.info,
            canRetry: true,
          ),
        ProcessingFailure() => (
            title: 'Processing Failed',
            message: failure.message,
            type: NotificationType.error,
            canRetry: true,
          ),
        PdfFailure() => (
            title: 'PDF Error',
            message: failure.message,
            type: NotificationType.error,
            canRetry: true,
          ),
        PermissionFailure() => (
            title: 'Permission Required',
            message: failure.message,
            type: NotificationType.warning,
            canRetry: false,
          ),
        CameraFailure() => (
            title: 'Camera Error',
            message: failure.message,
            type: NotificationType.error,
            canRetry: true,
          ),
        FileFailure() || StorageFailure() => (
            title: 'Storage Error',
            message: failure.message,
            type: NotificationType.error,
            canRetry: true,
          ),
        NativeChannelFailure() => (
            title: 'Platform Error',
            message: failure.message,
            type: NotificationType.error,
            canRetry: true,
          ),
        RouteArgumentFailure() => (
            title: 'Navigation Error',
            message: failure.message,
            type: NotificationType.error,
            canRetry: false,
          ),
      };
}
