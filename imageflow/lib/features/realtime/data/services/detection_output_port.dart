import 'dart:typed_data';
import 'dart:ui';

import '../../../../core/models/detected_object_info.dart';
import '../../../../core/models/normalized_corners.dart';

/// Output boundary for the realtime detection pipeline.
///
/// The pipeline (data layer) produces per-frame detection results but must not
/// depend on how they are rendered. It writes them through this port; the
/// presentation layer's overlay store implements the port. This is the
/// Dependency Inversion that keeps the arrow pointing data <- presentation:
/// both sides depend on this abstraction, so `data/` never imports `presentation/`.
///
/// The contract is intentionally the exact set of store operations the pipeline
/// uses — no more — so the inversion is behavior-preserving.
abstract interface class DetectionOutputPort {
  /// Current document status label. The pipeline reads this back to decide
  /// document state transitions.
  ///
  /// NOTE: this read-back is a lingering presentation concern leaking into the
  /// pipeline. It is preserved as-is by the inversion; a later change can move
  /// the transition decision out of the pipeline so the port becomes write-only.
  String get documentStatusLabel;

  // --- Face ---

  void applyFaceGeometry({
    required List<Rect> nextFaceRects,
    required List<List<Offset>> nextFaceContours,
  });

  void setFaceNotFoundState();

  void setFaceDetectedStatus(int count);

  bool shouldBuildFacePanelPreview({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  });

  void setFacePreviewBytes(Uint8List? bytes);

  void rememberFacePreviewMotion({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  });

  // --- Document ---

  void setDocumentSearchingState();

  void setDocumentFoundState();

  void setDocumentCorners(NormalizedCorners? corners);

  void setDocumentPreviewBytes(Uint8List? bytes);

  bool shouldBuildDocumentPanelPreview({
    required NormalizedCorners corners,
    required DateTime now,
  });

  void rememberDocumentPreviewMotion({
    required NormalizedCorners corners,
    required DateTime now,
  });

  void resetDocumentPreviewMotionState();

  // --- Objects ---

  /// Publishes the latest detected objects (normalized 0-1 boxes with COCO
  /// labels) for the realtime overlay. Passing an empty list clears the boxes.
  void setDetectedObjects(List<DetectedObjectInfo> objects);
}
