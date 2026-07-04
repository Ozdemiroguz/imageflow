import 'dart:typed_data';
import 'dart:ui';

import 'package:get/get.dart';

import '../../../../core/models/detected_object_info.dart';
import '../../../../core/models/normalized_corners.dart';
import '../../../../core/utils/num_utils.dart';
import '../../data/services/detection_output_port.dart';
import '../enums/realtime_preview_target.dart';
import '../models/capture_realtime_config.dart';
import '../models/realtime_overlay_state.dart';

/// Presentation helper for realtime overlay state.
///
/// Implements [DetectionOutputPort]: the data-layer detection pipeline writes
/// results through that abstraction, so the dependency points presentation ->
/// data (never the reverse). This is the store's role as the output boundary.
///
/// This is a plain class, not a GetxService.
class RealtimeOverlayStateStore implements DetectionOutputPort {
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
  final detectedObjects = <DetectedObjectInfo>[].obs;
  final documentCorners = Rxn<NormalizedCorners>();
  final facePreviewBytes = Rxn<Uint8List>();
  final documentPreviewBytes = Rxn<Uint8List>();
  final faceStatus = ''.obs;
  final documentStatus = ''.obs;
  final expandedPreviewTarget = Rxn<RealtimePreviewTarget>();
  int? _lastFacePreviewHash;
  int? _lastDocumentPreviewHash;

  /// Read side of [DetectionOutputPort]: the raw current document status label.
  @override
  String get documentStatusLabel => documentStatus.value;

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

  @override
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

  @override
  void setFaceNotFoundState() {
    if (faceStatus.value != _config.faceNotFoundStatus) {
      faceStatus.value = _config.faceNotFoundStatus;
    }
    setFacePreviewBytes(null);
    _overlayState.resetFacePreviewMotionState();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  void setDocumentNoTextState() {
    setDocumentStatus(_config.documentNoTextStatus);
    setDocumentCorners(null);
    setDocumentPreviewBytes(null);
    resetDocumentPreviewMotionState();
  }

  @override
  void setDocumentSearchingState() {
    setDocumentStatus(_config.documentEdgeSearchingStatus);
  }

  @override
  void setDocumentFoundState() {
    setDocumentStatus(_config.documentFoundStatus);
  }

  void setDocumentStatus(String status) {
    if (documentStatus.value != status) {
      documentStatus.value = status;
    }
  }

  @override
  void setDocumentCorners(NormalizedCorners? corners) {
    if (_overlayState.hasDocumentCornersChanged(
      documentCorners.value,
      corners,
    )) {
      documentCorners.value = corners;
    }
  }

  @override
  bool shouldBuildDocumentPanelPreview({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    return _overlayState.shouldBuildDocumentPanelPreview(
      corners: corners,
      now: now,
    );
  }

  @override
  void rememberDocumentPreviewMotion({
    required NormalizedCorners corners,
    required DateTime now,
  }) {
    _overlayState.rememberDocumentPreviewMotion(corners: corners, now: now);
  }

  @override
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

  @override
  void resetDocumentPreviewMotionState() {
    _overlayState.resetDocumentPreviewMotionState();
  }

  @override
  void setDetectedObjects(List<DetectedObjectInfo> objects) {
    if (_overlayState.hasDetectedObjectsChanged(detectedObjects, objects)) {
      detectedObjects.assignAll(objects);
    }
  }

  void resetAll() {
    _overlayState.resetAll();
    faceRects.clear();
    faceContours.clear();
    detectedObjects.clear();
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
    final step = clampInt((length / sampleCount).ceil(), 1, length);

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
}
