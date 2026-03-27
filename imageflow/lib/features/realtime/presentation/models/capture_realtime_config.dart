import 'package:camera/camera.dart';

import '../enums/realtime_native_rotation_strategy.dart';

class CaptureRealtimeConfig {
  const CaptureRealtimeConfig({
    required this.faceInterval,
    required this.ocrInterval,
    required this.edgeInterval,
    required this.facePanelInterval,
    required this.documentPanelInterval,
    required this.minFaceRectDelta,
    required this.minFaceContourDelta,
    required this.minDocumentCornerDelta,
    required this.faceScanningStatus,
    required this.faceNotFoundStatus,
    required this.faceFoundStatusTemplate,
    required this.facePrimaryPreviewLabel,
    required this.faceDetectedPreviewLabel,
    required this.documentScanningStatus,
    required this.documentNoTextStatus,
    required this.documentEdgeSearchingStatus,
    required this.documentFoundStatus,
    required this.realtimeStreamStartDelay,
    required this.resolutionPreset,
    required this.imageFormatGroup,
    required this.nativeRotationStrategy,
    required this.frameImageUsesNativeRotation,
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

  static const ios = CaptureRealtimeConfig(
    faceInterval: Duration(milliseconds: 180),
    ocrInterval: Duration(milliseconds: 850),
    edgeInterval: Duration(milliseconds: 260),
    facePanelInterval: Duration(milliseconds: 700),
    documentPanelInterval: Duration(milliseconds: 800),
    minFaceRectDelta: 0.015,
    minFaceContourDelta: 0.02,
    minDocumentCornerDelta: 0.015,
    faceScanningStatus: 'Scanning for faces...',
    faceNotFoundStatus: 'No face detected',
    faceFoundStatusTemplate: 'Face found ({count})',
    facePrimaryPreviewLabel: 'Preview: primary face',
    faceDetectedPreviewLabel: 'Preview: detected face',
    documentScanningStatus: 'Scanning for document...',
    documentNoTextStatus: 'No document',
    documentEdgeSearchingStatus: 'Searching document edges...',
    documentFoundStatus: 'Document found',
    realtimeStreamStartDelay: Duration(milliseconds: 500),
    resolutionPreset: ResolutionPreset.low,
    imageFormatGroup: ImageFormatGroup.bgra8888,
    nativeRotationStrategy: RealtimeNativeRotationStrategy.sensorOnly,
    frameImageUsesNativeRotation: false,
  );

  static const android = CaptureRealtimeConfig(
    faceInterval: Duration(milliseconds: 180),
    ocrInterval: Duration(milliseconds: 850),
    edgeInterval: Duration(milliseconds: 260),
    facePanelInterval: Duration(milliseconds: 700),
    documentPanelInterval: Duration(milliseconds: 800),
    minFaceRectDelta: 0.015,
    minFaceContourDelta: 0.02,
    minDocumentCornerDelta: 0.015,
    faceScanningStatus: 'Scanning for faces...',
    faceNotFoundStatus: 'No face detected',
    faceFoundStatusTemplate: 'Face found ({count})',
    facePrimaryPreviewLabel: 'Preview: primary face',
    faceDetectedPreviewLabel: 'Preview: detected face',
    documentScanningStatus: 'Scanning for document...',
    documentNoTextStatus: 'No document',
    documentEdgeSearchingStatus: 'Searching document edges...',
    documentFoundStatus: 'Document found',
    realtimeStreamStartDelay: Duration.zero,
    resolutionPreset: ResolutionPreset.medium,
    imageFormatGroup: ImageFormatGroup.yuv420,
    nativeRotationStrategy:
        RealtimeNativeRotationStrategy.sensorAndDeviceByLens,
    frameImageUsesNativeRotation: true,
  );
}
