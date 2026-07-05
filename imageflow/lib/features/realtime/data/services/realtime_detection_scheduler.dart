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
    required Duration objectInterval,
  }) : _faceInterval = faceInterval,
       _ocrInterval = ocrInterval,
       _edgeInterval = edgeInterval,
       _facePanelInterval = facePanelInterval,
       _documentPanelInterval = documentPanelInterval,
       _objectInterval = objectInterval;

  // The three detector intervals are mutable so the scan-budget engine can
  // re-split them at runtime when the user re-prioritizes or toggles a detector
  // (see [updateDetectorIntervals]). The OCR and panel intervals are fixed —
  // OCR isn't run in realtime and the panels are a UI-refresh throttle, so
  // neither takes a budget share.
  Duration _faceInterval;
  Duration _edgeInterval;
  Duration _objectInterval;
  final Duration _ocrInterval;
  final Duration _facePanelInterval;
  final Duration _documentPanelInterval;

  /// Re-point the detector intervals (e.g. after the scan budget re-splits when
  /// the enabled set or priority weights change). Only the detectors present in
  /// each argument change; a null keeps the current value. This does not reset
  /// the last-run timestamps, so the new cadence takes effect from the next
  /// eligible frame without forcing an immediate re-run.
  void updateDetectorIntervals({
    Duration? face,
    Duration? edge,
    Duration? object,
  }) {
    if (face != null) _faceInterval = face;
    if (edge != null) _edgeInterval = edge;
    if (object != null) _objectInterval = object;
  }

  DateTime? _lastFaceRunAt;
  DateTime? _lastOcrRunAt;
  DateTime? _lastEdgeRunAt;
  DateTime? _lastFacePanelAt;
  DateTime? _lastDocumentPanelAt;
  DateTime? _lastObjectRunAt;

  var _isFaceBusy = false;
  var _isOcrBusy = false;
  var _isEdgeBusy = false;
  var _isObjectBusy = false;
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

  // Edge (document corner) detection is NO LONGER gated on OCR text. A document
  // is always a rectangle but does not always contain text, so requiring text
  // first missed text-less documents (blank pages, drawings, forms). The scene
  // gate at the top of the pipeline already skips blank frames, so edge just
  // needs its own busy/interval guard here.
  bool tryBeginEdgeDetection(DateTime now) {
    if (_isEdgeBusy) return false;
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

  bool tryBeginObjectDetection(DateTime now) {
    if (_isObjectBusy) return false;
    if (_lastObjectRunAt != null &&
        now.difference(_lastObjectRunAt!) < _objectInterval) {
      return false;
    }
    _isObjectBusy = true;
    _lastObjectRunAt = now;
    return true;
  }

  void endObjectDetection() {
    _isObjectBusy = false;
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
    _lastObjectRunAt = null;
    _isFaceBusy = false;
    _isOcrBusy = false;
    _isEdgeBusy = false;
    _isObjectBusy = false;
    _hasOcrText = false;
  }
}
