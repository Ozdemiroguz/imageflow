/// Frame-scheduling core for the realtime detection pipeline.
///
/// Pure timing/throttle logic: it decides whether a given detector (face, OCR,
/// edge) or preview panel may run for the current frame, based on per-detector
/// intervals and busy guards. No framework, no camera, no state store — this is
/// the data-layer scheduler consumed by [RealtimeDetectionPipeline].
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

  // --- Detection slots: acquire/release pairs -------------------------------
  //
  // `tryBegin*Detection` acquires a slot: it returns true and LOCKS the
  // detector busy iff the detector is free and its interval has elapsed. On
  // true, the caller MUST later call the matching `end*Detection` (do it in a
  // `finally`) or the detector stays busy forever. On false, no slot was taken
  // and no release is needed. This is a try-acquire, not a pure predicate — the
  // `tryBegin` name signals both the possible failure and the state change.

  bool tryBeginFaceDetection(DateTime now) {
    if (_isFaceBusy) return false;
    if (_lastFaceRunAt != null &&
        now.difference(_lastFaceRunAt!) < _faceInterval) {
      return false;
    }
    _isFaceBusy = true;
    _lastFaceRunAt = now;
    return true;
  }

  void endFaceDetection() {
    _isFaceBusy = false;
  }

  bool tryBeginOcrDetection(DateTime now) {
    if (_isOcrBusy) return false;
    if (_lastOcrRunAt != null &&
        now.difference(_lastOcrRunAt!) < _ocrInterval) {
      return false;
    }
    _isOcrBusy = true;
    _lastOcrRunAt = now;
    return true;
  }

  void endOcrDetection({bool? hasText}) {
    _isOcrBusy = false;
    if (hasText != null) {
      _hasOcrText = hasText;
    }
  }

  bool tryBeginEdgeDetection(DateTime now) {
    if (!_hasOcrText || _isEdgeBusy) return false;
    if (_lastEdgeRunAt != null &&
        now.difference(_lastEdgeRunAt!) < _edgeInterval) {
      return false;
    }
    _isEdgeBusy = true;
    _lastEdgeRunAt = now;
    return true;
  }

  void endEdgeDetection() {
    _isEdgeBusy = false;
  }

  // --- Preview-panel throttle slots -----------------------------------------
  //
  // `tryTake*PanelSlot` is a pure throttle: it returns true and marks "now" as
  // the last panel-build time iff enough time has elapsed. There is NO busy
  // lock and NO matching release — taking the slot is the whole operation.

  bool tryTakeFacePanelSlot(DateTime now) {
    if (_lastFacePanelAt != null &&
        now.difference(_lastFacePanelAt!) < _facePanelInterval) {
      return false;
    }
    _lastFacePanelAt = now;
    return true;
  }

  bool tryTakeDocumentPanelSlot(DateTime now) {
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
