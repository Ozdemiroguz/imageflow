import 'dart:ui';

import '../../../../core/models/detected_object_info.dart';
import '../../../../core/models/normalized_corners.dart';
import 'capture_realtime_config.dart';

class RealtimeOverlayState {
  RealtimeOverlayState({required CaptureRealtimeConfig config})
    : _config = config;

  final CaptureRealtimeConfig _config;

  Rect? _lastFacePreviewRect;
  List<Offset> _lastFacePreviewContour = const [];
  DateTime? _lastFacePreviewBuiltAt;

  NormalizedCorners? _lastDocumentPreviewCorners;
  DateTime? _lastDocumentPreviewBuiltAt;

  bool hasFaceRectsChanged(List<Rect> current, List<Rect> next) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (!_rectAlmostEqual(a, b, _config.minFaceRectDelta)) {
        return true;
      }
    }
    return false;
  }

  bool hasFaceContoursChanged(
    List<List<Offset>> current,
    List<List<Offset>> next,
  ) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j++) {
        final da = (a[j].dx - b[j].dx).abs();
        final db = (a[j].dy - b[j].dy).abs();
        if (da > _config.minFaceContourDelta ||
            db > _config.minFaceContourDelta) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasDocumentCornersChanged(
    NormalizedCorners? current,
    NormalizedCorners? next,
  ) {
    if (current == null && next == null) return false;
    if (current == null || next == null) return true;

    return !_pointAlmostEqual(current.topLeft, next.topLeft) ||
        !_pointAlmostEqual(current.topRight, next.topRight) ||
        !_pointAlmostEqual(current.bottomRight, next.bottomRight) ||
        !_pointAlmostEqual(current.bottomLeft, next.bottomLeft);
  }

  /// Whether the detected-object set changed enough to be worth repainting.
  /// Repaints on a count change, any label/order change, or a box that moved
  /// past [CaptureRealtimeConfig.minObjectRectDelta] — jitter below that is
  /// ignored so the overlay does not thrash on sub-pixel noise.
  bool hasDetectedObjectsChanged(
    List<DetectedObjectInfo> current,
    List<DetectedObjectInfo> next,
  ) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.label != b.label) return true;
      final r = _config.minObjectRectDelta;
      if ((a.rect.left - b.rect.left).abs() > r ||
          (a.rect.top - b.rect.top).abs() > r ||
          (a.rect.right - b.rect.right).abs() > r ||
          (a.rect.bottom - b.rect.bottom).abs() > r) {
        return true;
      }
    }
    return false;
  }

  bool shouldBuildFacePanelPreview({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  }) {
    if (_lastFacePreviewBuiltAt == null ||
        now.difference(_lastFacePreviewBuiltAt!) >= _config.facePanelInterval) {
      return true;
    }

    final lastRect = _lastFacePreviewRect;
    if (lastRect == null) return true;

    if (!_rectAlmostEqual(lastRect, faceRect, _config.minFaceRectDelta)) {
      return true;
    }

    if (_lastFacePreviewContour.length != faceContour.length) {
      return true;
    }

    for (var i = 0; i < faceContour.length; i++) {
      final prev = _lastFacePreviewContour[i];
      final curr = faceContour[i];
      if ((prev.dx - curr.dx).abs() > _config.minFaceContourDelta ||
          (prev.dy - curr.dy).abs() > _config.minFaceContourDelta) {
        return true;
      }
    }

    return false;
  }

  void rememberFacePreviewMotion({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  }) {
    _lastFacePreviewRect = faceRect;
    _lastFacePreviewContour = List<Offset>.from(faceContour);
    _lastFacePreviewBuiltAt = now;
  }

  bool shouldBuildDocumentPanelPreview({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    if (_lastDocumentPreviewBuiltAt == null ||
        now.difference(_lastDocumentPreviewBuiltAt!) >=
            _config.documentPanelInterval) {
      return true;
    }

    final last = _lastDocumentPreviewCorners;
    if (last == null) return true;

    return !_pointAlmostEqual(last.topLeft, corners.topLeft) ||
        !_pointAlmostEqual(last.topRight, corners.topRight) ||
        !_pointAlmostEqual(last.bottomRight, corners.bottomRight) ||
        !_pointAlmostEqual(last.bottomLeft, corners.bottomLeft);
  }

  void rememberDocumentPreviewMotion({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    _lastDocumentPreviewCorners = corners;
    _lastDocumentPreviewBuiltAt = now;
  }

  void resetFacePreviewMotionState() {
    _lastFacePreviewRect = null;
    _lastFacePreviewContour = const [];
    _lastFacePreviewBuiltAt = null;
  }

  void resetDocumentPreviewMotionState() {
    _lastDocumentPreviewCorners = null;
    _lastDocumentPreviewBuiltAt = null;
  }

  void resetAll() {
    resetFacePreviewMotionState();
    resetDocumentPreviewMotionState();
  }

  bool _rectAlmostEqual(Rect a, Rect b, double epsilon) {
    return (a.left - b.left).abs() <= epsilon &&
        (a.top - b.top).abs() <= epsilon &&
        (a.width - b.width).abs() <= epsilon &&
        (a.height - b.height).abs() <= epsilon;
  }

  bool _pointAlmostEqual(({double x, double y}) a, ({double x, double y}) b) {
    return (a.x - b.x).abs() <= _config.minDocumentCornerDelta &&
        (a.y - b.y).abs() <= _config.minDocumentCornerDelta;
  }
}
