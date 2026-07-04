import 'package:camera/camera.dart';

import 'realtime_native_rotation_strategy.dart';

class CaptureRealtimeConfig {
  // Timing, thresholds, and UI labels are identical across platforms, so they
  // default here and only the platform-specific camera fields (resolution,
  // format, rotation, start delay) are supplied per preset. This keeps the
  // ios/android presets free of duplicated boilerplate.
  const CaptureRealtimeConfig({
    required this.realtimeStreamStartDelay,
    required this.resolutionPreset,
    required this.imageFormatGroup,
    required this.nativeRotationStrategy,
    required this.frameImageUsesNativeRotation,
    this.faceInterval = const Duration(milliseconds: 180),
    this.ocrInterval = const Duration(milliseconds: 850),
    this.edgeInterval = const Duration(milliseconds: 260),
    this.facePanelInterval = const Duration(milliseconds: 700),
    this.documentPanelInterval = const Duration(milliseconds: 800),
    this.minFaceRectDelta = 0.015,
    this.minFaceContourDelta = 0.02,
    this.minDocumentCornerDelta = 0.015,
    this.faceScanningStatus = 'Scanning for faces...',
    this.faceNotFoundStatus = 'No face detected',
    this.faceFoundStatusTemplate = 'Face found ({count})',
    this.facePrimaryPreviewLabel = 'Preview: primary face',
    this.faceDetectedPreviewLabel = 'Preview: detected face',
    this.documentScanningStatus = 'Scanning for document...',
    this.documentNoTextStatus = 'No document',
    this.documentEdgeSearchingStatus = 'Searching document edges...',
    this.documentFoundStatus = 'Document found',
  });

  final Duration faceInterval;
  final Duration ocrInterval;
  final Duration edgeInterval;
  final Duration facePanelInterval;
  final Duration documentPanelInterval;

  final double minFaceRectDelta;
  final double minFaceContourDelta;
  final double minDocumentCornerDelta;

  final String faceScanningStatus;
  final String faceNotFoundStatus;

  /// Format template for face found status. Use `{count}` as placeholder.
  /// Example: `'Face found ({count})'` → `'Face found (2)'`
  final String faceFoundStatusTemplate;
  final String facePrimaryPreviewLabel;
  final String faceDetectedPreviewLabel;

  final String documentScanningStatus;
  final String documentNoTextStatus;
  final String documentEdgeSearchingStatus;
  final String documentFoundStatus;

  final Duration realtimeStreamStartDelay;
  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup imageFormatGroup;
  final RealtimeNativeRotationStrategy nativeRotationStrategy;
  final bool frameImageUsesNativeRotation;

  static const defaults = android;

  /// iOS: BGRA frames, sensor-only rotation, a short warm-up delay.
  static const ios = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration(milliseconds: 500),
    resolutionPreset: ResolutionPreset.low,
    imageFormatGroup: ImageFormatGroup.bgra8888,
    nativeRotationStrategy: RealtimeNativeRotationStrategy.sensorOnly,
    frameImageUsesNativeRotation: false,
  );

  /// Android: YUV420 frames, native (sensor+device-by-lens) rotation.
  static const android = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration.zero,
    resolutionPreset: ResolutionPreset.medium,
    imageFormatGroup: ImageFormatGroup.yuv420,
    nativeRotationStrategy:
        RealtimeNativeRotationStrategy.sensorAndDeviceByLens,
    frameImageUsesNativeRotation: true,
  );
}
