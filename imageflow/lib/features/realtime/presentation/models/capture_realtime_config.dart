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
    this.objectInterval = const Duration(milliseconds: 300),
    this.facePanelInterval = const Duration(milliseconds: 700),
    this.documentPanelInterval = const Duration(milliseconds: 800),
    this.minFaceRectDelta = 0.015,
    this.minFaceContourDelta = 0.02,
    this.minDocumentCornerDelta = 0.015,
    this.minObjectRectDelta = 0.02,
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
  final Duration objectInterval;
  final Duration facePanelInterval;
  final Duration documentPanelInterval;

  final double minFaceRectDelta;
  final double minFaceContourDelta;
  final double minDocumentCornerDelta;
  final double minObjectRectDelta;

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
  ///
  /// Resolution is `veryHigh` (1080p): on-device profiling showed the iOS
  /// realtime pipeline with the UI thread near-idle and zero jank at 60fps
  /// (Vision runs on the ANE), so there's ample frame budget for a crisp preview
  /// on Retina displays.
  static const ios = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration(milliseconds: 500),
    resolutionPreset: ResolutionPreset.veryHigh,
    imageFormatGroup: ImageFormatGroup.bgra8888,
    nativeRotationStrategy: RealtimeNativeRotationStrategy.sensorOnly,
    frameImageUsesNativeRotation: false,
  );

  /// Android: YUV420 frames, native (sensor+device-by-lens) rotation.
  ///
  /// Resolution is `veryHigh` (1080p) for a crisp preview. Android has no ANE,
  /// so the object/edge detectors run on CPU/GPU — validate on-device that the
  /// frame budget still holds; drop to `high` if a low-end device janks.
  static const android = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration.zero,
    resolutionPreset: ResolutionPreset.veryHigh,
    imageFormatGroup: ImageFormatGroup.yuv420,
    nativeRotationStrategy:
        RealtimeNativeRotationStrategy.sensorAndDeviceByLens,
    frameImageUsesNativeRotation: true,
  );
}
