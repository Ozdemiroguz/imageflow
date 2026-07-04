import '../../../../core/utils/perf_trace.dart';

class RealtimeFramePerfTracker {
  RealtimeFramePerfTracker({this.tag = 'PerfRealtime', this.windowMs = 3000});

  final String tag;
  final int windowMs;

  DateTime? _windowStartedAt;
  var _frameCount = 0;
  var _frameTotalMs = 0;
  var _frameMaxMs = 0;
  var _ocrCount = 0;
  var _ocrTotalMs = 0;
  var _faceCount = 0;
  var _faceTotalMs = 0;
  var _edgeCount = 0;
  var _edgeTotalMs = 0;
  var _objectCount = 0;
  var _objectTotalMs = 0;

  void recordSample({
    required DateTime now,
    required int frameMs,
    int? ocrMs,
    int? faceMs,
    int? edgeMs,
    int? objectMs,
  }) {
    if (!PerfTrace.isEnabled || frameMs < 0) return;

    _windowStartedAt ??= now;
    _frameCount += 1;
    _frameTotalMs += frameMs;
    if (frameMs > _frameMaxMs) {
      _frameMaxMs = frameMs;
    }

    if (ocrMs != null && ocrMs >= 0) {
      _ocrCount += 1;
      _ocrTotalMs += ocrMs;
    }
    if (faceMs != null && faceMs >= 0) {
      _faceCount += 1;
      _faceTotalMs += faceMs;
    }
    if (edgeMs != null && edgeMs >= 0) {
      _edgeCount += 1;
      _edgeTotalMs += edgeMs;
    }
    if (objectMs != null && objectMs >= 0) {
      _objectCount += 1;
      _objectTotalMs += objectMs;
    }

    final elapsedMs = now.difference(_windowStartedAt!).inMilliseconds;
    if (elapsedMs < windowMs) return;

    final avgFrameMs = (_frameTotalMs / _frameCount).round();
    final avgOcrMs = _ocrCount == 0 ? 0 : (_ocrTotalMs / _ocrCount).round();
    final avgFaceMs = _faceCount == 0 ? 0 : (_faceTotalMs / _faceCount).round();
    final avgEdgeMs = _edgeCount == 0 ? 0 : (_edgeTotalMs / _edgeCount).round();
    final avgObjectMs = _objectCount == 0
        ? 0
        : (_objectTotalMs / _objectCount).round();

    final details =
        'window=${elapsedMs}ms'
        ' frames=$_frameCount'
        ' maxFrame=${_frameMaxMs}ms'
        ' ocr=$_ocrCount/$avgOcrMs'
        ' face=$_faceCount/$avgFaceMs'
        ' edge=$_edgeCount/$avgEdgeMs'
        ' object=$_objectCount/$avgObjectMs';

    if (_frameMaxMs >= 32) {
      PerfTrace.warning(
        'realtime.window.avgFrame',
        avgFrameMs,
        tag: tag,
        details: details,
      );
    } else {
      PerfTrace.info(
        'realtime.window.avgFrame',
        avgFrameMs,
        tag: tag,
        details: details,
      );
    }

    _resetWindow(now);
  }

  void _resetWindow(DateTime now) {
    _windowStartedAt = now;
    _frameCount = 0;
    _frameTotalMs = 0;
    _frameMaxMs = 0;
    _ocrCount = 0;
    _ocrTotalMs = 0;
    _faceCount = 0;
    _faceTotalMs = 0;
    _edgeCount = 0;
    _edgeTotalMs = 0;
    _objectCount = 0;
    _objectTotalMs = 0;
  }
}
