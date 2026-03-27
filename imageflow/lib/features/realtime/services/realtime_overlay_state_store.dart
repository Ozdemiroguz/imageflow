import 'dart:typed_data';
import 'dart:ui';

import 'package:get/get.dart';

import '../../../core/models/normalized_corners.dart';
import '../presentation/enums/realtime_preview_target.dart';
import '../presentation/models/capture_realtime_config.dart';
import '../presentation/models/realtime_overlay_state.dart';

/// Presentation helper for realtime overlay state.
/// This is a plain class, not a GetxService.
class RealtimeOverlayStateStore {
  RealtimeOverlayStateStore({
    required CaptureRealtimeConfig config,
    required RealtimeOverlayState overlayState,
  }) : _config = config,
       _overlayState = overlayState {
    faceStatus.value = _config.faceScanningStatus;
    documentStatus.value = _config.documentScanningStatus;
  }

  final CaptureRealtimeConfig _config;
  final RealtimeOverlayState _overlayState;

  final faceRects = <Rect>[].obs;
  final faceContours = <List<Offset>>[].obs;
  final documentCorners = Rxn<NormalizedCorners>();
  final facePreviewBytes = Rxn<Uint8List>();
  final documentPreviewBytes = Rxn<Uint8List>();
  final faceStatus = ''.obs;
  final documentStatus = ''.obs;
  final expandedPreviewTarget = Rxn<RealtimePreviewTarget>();
  int? _lastFacePreviewHash;
  int? _lastDocumentPreviewHash;

  bool get isFacePreviewExpanded =>
      expandedPreviewTarget.value == RealtimePreviewTarget.face;

  bool get isDocumentPreviewExpanded =>
      expandedPreviewTarget.value == RealtimePreviewTarget.document;

  void toggleExpandedPreviewTarget(RealtimePreviewTarget target) {
    expandedPreviewTarget.value = expandedPreviewTarget.value == target
        ? null
        : target;
  }

  void clearExpandedPreviewTarget() {
    expandedPreviewTarget.value = null;
  }

  void applyFaceGeometry({
    required List<Rect> nextFaceRects,
    required List<List<Offset>> nextFaceContours,
  }) {
    if (_overlayState.hasFaceRectsChanged(faceRects, nextFaceRects)) {
      faceRects.assignAll(nextFaceRects);
    }
    if (_overlayState.hasFaceContoursChanged(faceContours, nextFaceContours)) {
      faceContours.assignAll(nextFaceContours);
    }
  }

  void setFaceNotFoundState() {
    if (faceStatus.value != _config.faceNotFoundStatus) {
      faceStatus.value = _config.faceNotFoundStatus;
    }
    setFacePreviewBytes(null);
    _overlayState.resetFacePreviewMotionState();
  }

  void setFaceDetectedStatus(int count) {
    final detectedLabel = _config.faceFoundStatusTemplate.replaceFirst(
      '{count}',
      '$count',
    );
    final previewLabel = count > 1
        ? _config.facePrimaryPreviewLabel
        : _config.faceDetectedPreviewLabel;
    final nextFaceStatus = '$detectedLabel • $previewLabel';
    if (faceStatus.value != nextFaceStatus) {
      faceStatus.value = nextFaceStatus;
    }
  }

  bool shouldBuildFacePanelPreview({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  }) {
    return _overlayState.shouldBuildFacePanelPreview(
      faceRect: faceRect,
      faceContour: faceContour,
      now: now,
    );
  }

  void rememberFacePreviewMotion({
    required Rect faceRect,
    required List<Offset> faceContour,
    required DateTime now,
  }) {
    _overlayState.rememberFacePreviewMotion(
      faceRect: faceRect,
      faceContour: faceContour,
      now: now,
    );
  }

  void setFacePreviewBytes(Uint8List? bytes) {
    if (bytes == null) {
      _lastFacePreviewHash = null;
      if (facePreviewBytes.value != null) {
        facePreviewBytes.value = null;
      }
      return;
    }
    final nextHash = _bytesSignature(bytes);
    if (_lastFacePreviewHash == nextHash) return;
    _lastFacePreviewHash = nextHash;
    facePreviewBytes.value = bytes;
  }

  void setDocumentNoTextState() {
    setDocumentStatus(_config.documentNoTextStatus);
    setDocumentCorners(null);
    setDocumentPreviewBytes(null);
    resetDocumentPreviewMotionState();
  }

  void setDocumentSearchingState() {
    setDocumentStatus(_config.documentEdgeSearchingStatus);
  }

  void setDocumentFoundState() {
    setDocumentStatus(_config.documentFoundStatus);
  }

  void setDocumentStatus(String status) {
    if (documentStatus.value != status) {
      documentStatus.value = status;
    }
  }

  void setDocumentCorners(NormalizedCorners? corners) {
    if (_overlayState.hasDocumentCornersChanged(
      documentCorners.value,
      corners,
    )) {
      documentCorners.value = corners;
    }
  }

  bool shouldBuildDocumentPanelPreview({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    return _overlayState.shouldBuildDocumentPanelPreview(
      corners: corners,
      now: now,
    );
  }

  void rememberDocumentPreviewMotion({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    _overlayState.rememberDocumentPreviewMotion(corners: corners, now: now);
  }

  void setDocumentPreviewBytes(Uint8List? bytes) {
    if (bytes == null) {
      _lastDocumentPreviewHash = null;
      if (documentPreviewBytes.value != null) {
        documentPreviewBytes.value = null;
      }
      return;
    }
    final nextHash = _bytesSignature(bytes);
    if (_lastDocumentPreviewHash == nextHash) return;
    _lastDocumentPreviewHash = nextHash;
    documentPreviewBytes.value = bytes;
  }

  void resetDocumentPreviewMotionState() {
    _overlayState.resetDocumentPreviewMotionState();
  }

  void resetAll() {
    _overlayState.resetAll();
    faceRects.clear();
    faceContours.clear();
    documentCorners.value = null;
    facePreviewBytes.value = null;
    documentPreviewBytes.value = null;
    _lastFacePreviewHash = null;
    _lastDocumentPreviewHash = null;
    faceStatus.value = _config.faceScanningStatus;
    documentStatus.value = _config.documentScanningStatus;
    expandedPreviewTarget.value = null;
  }

  int _bytesSignature(Uint8List bytes) {
    // Lightweight sampled signature for preview dedupe.
    // We only need "probably unchanged" detection here, not cryptographic hash.
    final length = bytes.length;
    if (length == 0) return 0;

    var hash = 0x9E3779B97F4A7C15 ^ length;
    const sampleCount = 64;
    final step = _clampInt((length / sampleCount).ceil(), 1, length);

    for (var i = 0; i < length; i += step) {
      hash = _mix(hash, bytes[i]);
    }

    hash = _mix(hash, bytes[length - 1]);
    hash = _mix(hash, bytes[length ~/ 2]);
    return hash & 0xFFFFFFFFFFFFFFFF;
  }

  int _mix(int hash, int value) {
    final mixed = (hash ^ value) * 0x100000001b3;
    return mixed & 0xFFFFFFFFFFFFFFFF;
  }

  int _clampInt(int value, int min, int max) {
    return value < min ? min : (value > max ? max : value);
  }
}
