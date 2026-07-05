import 'package:camera/camera.dart';

import 'realtime_detection_modes.dart';
import 'realtime_native_rotation_strategy.dart';
import 'realtime_scan_budget.dart';

class CaptureRealtimeConfig {
  // Timing, thresholds, and UI labels are identical across platforms, so they
  // default here and only the platform-specific camera fields (resolution,
  // format, rotation, start delay) and the scan budget are supplied per preset.
  // This keeps the ios/android presets free of duplicated boilerplate.
  const CaptureRealtimeConfig({
    required this.realtimeStreamStartDelay,
    required this.resolutionPreset,
    required this.imageFormatGroup,
    required this.nativeRotationStrategy,
    required this.frameImageUsesNativeRotation,
    required this.scanBudget,
    this.ocrInterval = const Duration(milliseconds: 850),
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

  /// Total device scan budget + per-detector priority weights. The face / edge /
  /// object intervals are derived from this rather than hard-coded, so the sum
  /// of scan rates can never exceed the device's frame budget no matter which
  /// detectors are enabled (see [RealtimeScanBudget]).
  final RealtimeScanBudget scanBudget;

  /// Detector intervals derived from [scanBudget] assuming all three detectors
  /// are enabled — the initial/default split used to build the scheduler. When
  /// the user toggles modes or re-prioritizes at runtime, the controller
  /// recomputes intervals from [scanBudget] for the actually-enabled set; these
  /// getters are the startup values (and the fallback when nothing is toggled).
  Duration get faceInterval => _defaultIntervals[ScanDetector.face]!;
  Duration get edgeInterval => _defaultIntervals[ScanDetector.document]!;
  Duration get objectInterval => _defaultIntervals[ScanDetector.object]!;

  Map<ScanDetector, Duration> get _defaultIntervals =>
      scanBudget.intervalsFor(const RealtimeDetectionModes());

  final Duration ocrInterval;
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
  /// on Retina displays. The ANE headroom also affords a larger scan budget than
  /// Android.
  static const ios = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration(milliseconds: 500),
    resolutionPreset: ResolutionPreset.veryHigh,
    imageFormatGroup: ImageFormatGroup.bgra8888,
    nativeRotationStrategy: RealtimeNativeRotationStrategy.sensorOnly,
    frameImageUsesNativeRotation: false,
    // Vision runs on the ANE off the main thread, so iOS can afford a much
    // higher combined scan rate than Android without janking. This is an
    // aggressive ceiling so high-end devices can fully use their headroom; the
    // per-detector clamps in RealtimeScanBudget keep any single rate sane.
    scanBudget: RealtimeScanBudget(totalScansPerSecond: 20),
  );

  /// Android: YUV420 frames, native (sensor+device-by-lens) rotation.
  ///
  /// Resolution is `veryHigh` (1080p) for a crisp preview. Android has no ANE,
  /// so the object/edge detectors run on CPU/GPU. The scan budget is the ceiling
  /// that keeps all-detectors-on within the frame budget; on-device measurement
  /// on a mid-range device (Infinix, no ANE) held jank at 0 at this rate.
  static const android = CaptureRealtimeConfig(
    realtimeStreamStartDelay: Duration.zero,
    resolutionPreset: ResolutionPreset.veryHigh,
    imageFormatGroup: ImageFormatGroup.yuv420,
    nativeRotationStrategy:
        RealtimeNativeRotationStrategy.sensorAndDeviceByLens,
    frameImageUsesNativeRotation: true,
    // Aggressive ceiling (~14 scans/sec total) so high-end devices can fully use
    // their frame budget. A mid-range device (Infinix, no ANE) measured jank-0
    // at ~9/s with all three on, and the per-detector clamps in
    // RealtimeScanBudget cap any single rate — so the extra headroom is spent by
    // fast devices and simply clamped away on slower ones rather than janking.
    scanBudget: RealtimeScanBudget(totalScansPerSecond: 14),
  );
}
