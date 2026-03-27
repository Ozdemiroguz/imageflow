import 'package:camera/camera.dart';

class CameraCaptureConfig {
  const CameraCaptureConfig({
    required this.resolutionPreset,
    required this.imageFormatGroup,
  });

  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup imageFormatGroup;

  static const defaults = android;

  static const ios = CameraCaptureConfig(
    resolutionPreset: ResolutionPreset.high,
    imageFormatGroup: ImageFormatGroup.bgra8888,
  );

  static const android = CameraCaptureConfig(
    resolutionPreset: ResolutionPreset.medium,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );
}
