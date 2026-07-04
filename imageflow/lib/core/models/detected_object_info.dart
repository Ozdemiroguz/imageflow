/// A single detected object in normalized 0-1 frame coordinates.
///
/// Plugin-free value object — the anti-corruption boundary for the native
/// object detector (Core ML on iOS, EfficientDet-Lite0 via MediaPipe on
/// Android). Callers never see platform types; they get a label, a confidence,
/// a normalized rect, and an optional cross-frame tracking id.
class DetectedObjectInfo {
  const DetectedObjectInfo({
    required this.label,
    required this.confidence,
    required this.rect,
    this.trackingId,
  });

  /// Human-readable class name (e.g. 'person', 'cup'), or 'object' when the
  /// model reports a box without a usable label.
  final String label;

  /// Detection confidence in 0-1.
  final double confidence;

  /// Bounding box in normalized 0-1 coordinates, top-left origin.
  final ({double left, double top, double right, double bottom}) rect;

  /// Stable id for the same object across frames (realtime tracking); null when
  /// the detector doesn't track (e.g. single-image mode) or for a fresh object.
  final int? trackingId;
}
