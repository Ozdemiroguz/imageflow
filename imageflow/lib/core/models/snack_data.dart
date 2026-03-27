import '../enums/notification_type.dart';

class SnackData {
  const SnackData({
    required this.title,
    required this.message,
    this.type = NotificationType.success,
    this.duration = const Duration(seconds: 2),
  });

  const SnackData.success({
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 2),
  }) : type = NotificationType.success;

  const SnackData.error({
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 2),
  }) : type = NotificationType.error;

  const SnackData.info({
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 2),
  }) : type = NotificationType.info;

  const SnackData.warning({
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 2),
  }) : type = NotificationType.warning;

  final String title;
  final String message;
  final NotificationType type;
  final Duration duration;
}
