part 'failures_storage.dart';
part 'failures_file.dart';
part 'failures_processing.dart';
part 'failures_pdf.dart';
part 'failures_detection.dart';
part 'failures_camera.dart';
part 'failures_permission.dart';
part 'failures_native_channel.dart';
part 'failures_route_argument.dart';

sealed class Failure implements Exception {
  const Failure(this.message, {this.code, this.debugMessage});
  final String message;
  final String? code;
  final String? debugMessage;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
