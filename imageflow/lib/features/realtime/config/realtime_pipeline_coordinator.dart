import 'capture_realtime_config.dart';

class RealtimePipelineCoordinator {
  RealtimePipelineCoordinator({required CaptureRealtimeConfig config})
    : _config = config;

  final CaptureRealtimeConfig _config;

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
        now.difference(_lastFaceRunAt!) < _config.faceInterval) {
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
        now.difference(_lastOcrRunAt!) < _config.ocrInterval) {
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
        now.difference(_lastEdgeRunAt!) < _config.edgeInterval) {
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
        now.difference(_lastFacePanelAt!) < _config.facePanelInterval) {
      return false;
    }
    _lastFacePanelAt = now;
    return true;
  }

  bool tryScheduleDocumentPanel(DateTime now) {
    if (_lastDocumentPanelAt != null &&
        now.difference(_lastDocumentPanelAt!) < _config.documentPanelInterval) {
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
