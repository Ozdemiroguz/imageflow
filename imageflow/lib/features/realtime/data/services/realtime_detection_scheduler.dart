/// Frame-scheduling core for the realtime detection pipeline.
///
/// Pure timing/throttle logic: it decides whether a given detector (face, OCR,
/// edge) or preview panel may run for the current frame, based on per-detector
/// intervals and busy guards. No framework, no camera, no state store — this is
/// the data-layer scheduler consumed by [RealtimeDetectionPipelineCoordinator].
class RealtimeDetectionScheduler {
  RealtimeDetectionScheduler({
    required Duration faceInterval,
    required Duration ocrInterval,
    required Duration edgeInterval,
    required Duration facePanelInterval,
    required Duration documentPanelInterval,
  }) : _faceInterval = faceInterval,
       _ocrInterval = ocrInterval,
       _edgeInterval = edgeInterval,
       _facePanelInterval = facePanelInterval,
       _documentPanelInterval = documentPanelInterval;

  final Duration _faceInterval;
  final Duration _ocrInterval;
  final Duration _edgeInterval;
  final Duration _facePanelInterval;
  final Duration _documentPanelInterval;

  DateTime? _lastFaceRunAt;
  DateTime? _lastOcrRunAt;
  DateTime? _lastEdgeRunAt;
  DateTime? _lastFacePanelAt;
  DateTime? _lastDocumentPanelAt;

  var _isFaceBusy = false;
  var _isOcrBusy = false;
  var _isEdgeBusy = false;
  var _hasOcrText = false;

  bool get hasOcrText => _hasOcrText;

  bool tryScheduleFace(DateTime now) {
    if (_isFaceBusy) return false;
    if (_lastFaceRunAt != null &&
        now.difference(_lastFaceRunAt!) < _faceInterval) {
      return false;
    }
    _isFaceBusy = true;
    _lastFaceRunAt = now;
    return true;
  }

  void completeFace() {
    _isFaceBusy = false;
  }

  bool tryScheduleOcr(DateTime now) {
    if (_isOcrBusy) return false;
    if (_lastOcrRunAt != null &&
        now.difference(_lastOcrRunAt!) < _ocrInterval) {
      return false;
    }
    _isOcrBusy = true;
    _lastOcrRunAt = now;
    return true;
  }

  void completeOcr({bool? hasText}) {
    _isOcrBusy = false;
    if (hasText != null) {
      _hasOcrText = hasText;
    }
  }

  bool tryScheduleEdge(DateTime now) {
    if (!_hasOcrText || _isEdgeBusy) return false;
    if (_lastEdgeRunAt != null &&
        now.difference(_lastEdgeRunAt!) < _edgeInterval) {
      return false;
    }
    _isEdgeBusy = true;
    _lastEdgeRunAt = now;
    return true;
  }

  void completeEdge() {
    _isEdgeBusy = false;
  }

  bool tryScheduleFacePanel(DateTime now) {
    if (_lastFacePanelAt != null &&
        now.difference(_lastFacePanelAt!) < _facePanelInterval) {
      return false;
    }
    _lastFacePanelAt = now;
    return true;
  }

  bool tryScheduleDocumentPanel(DateTime now) {
    if (_lastDocumentPanelAt != null &&
        now.difference(_lastDocumentPanelAt!) < _documentPanelInterval) {
      return false;
    }
    _lastDocumentPanelAt = now;
    return true;
  }

  void reset() {
    _lastFaceRunAt = null;
    _lastOcrRunAt = null;
    _lastEdgeRunAt = null;
    _lastFacePanelAt = null;
    _lastDocumentPanelAt = null;
    _isFaceBusy = false;
    _isOcrBusy = false;
    _isEdgeBusy = false;
    _hasOcrText = false;
  }
}
