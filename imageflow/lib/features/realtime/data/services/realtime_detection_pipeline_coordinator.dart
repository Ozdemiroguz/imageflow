import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/models/normalized_corners.dart';
import '../../../../core/platform/corner_detector.dart';
import '../../../../core/utils/android_nv21.dart';
import '../../../../core/utils/log.dart';
import '../../../../core/utils/perf_trace.dart';
import '../../../../core/utils/realtime_input_image_factory.dart';
import '../../presentation/models/capture_realtime_config.dart';
import '../../presentation/models/realtime_pipeline_coordinator.dart';
import '../../presentation/state/realtime_overlay_state_store.dart';
import '../datasources/realtime_face_detection_service.dart';
import 'realtime_face_geometry_normalizer.dart';
import 'realtime_frame_perf_tracker.dart';
import '../datasources/realtime_ocr_gate_service.dart';
import 'realtime_preview_builder.dart';

/// Presentation helper for coordinating OCR, face, and document detection.
/// This is a plain class, not a GetxService.
class RealtimeDetectionPipelineCoordinator {
  RealtimeDetectionPipelineCoordinator({
    required CaptureRealtimeConfig config,
    required RealtimePipelineCoordinator pipelineCoordinator,
    required RealtimeOverlayStateStore overlayStateManager,
    required CornerDetector cornerDetectionService,
    required RealtimeFaceDetectionService faceDetectionService,
    required RealtimeOcrGateService ocrGateService,
    required RealtimePreviewBuilder previewBuilder,
    RealtimeFaceGeometryNormalizer? faceGeometryNormalizer,
    RealtimeFramePerfTracker? perfTracker,
  }) : _config = config,
       _pipelineCoordinator = pipelineCoordinator,
       _overlayStateManager = overlayStateManager,
       _cornerDetectionService = cornerDetectionService,
       _faceDetectionService = faceDetectionService,
       _ocrGateService = ocrGateService,
       _previewBuilder = previewBuilder,
       _faceGeometryNormalizer =
           faceGeometryNormalizer ??
           RealtimeFaceGeometryNormalizer(
             frameImageUsesNativeRotation: config.frameImageUsesNativeRotation,
           ),
       _perfTracker = perfTracker ?? RealtimeFramePerfTracker();

  static const _tag = 'RealtimeCamera';

  final CaptureRealtimeConfig _config;
  final RealtimePipelineCoordinator _pipelineCoordinator;
  final RealtimeOverlayStateStore _overlayStateManager;
  final CornerDetector _cornerDetectionService;
  final RealtimeFaceDetectionService _faceDetectionService;
  final RealtimeOcrGateService _ocrGateService;
  final RealtimePreviewBuilder _previewBuilder;
  final RealtimeFaceGeometryNormalizer _faceGeometryNormalizer;
  final RealtimeFramePerfTracker _perfTracker;

  Future<void> runOcrGate(
    CameraImage frame, {
    required InputImageRotation rotation,
    Uint8List? androidNv21Bytes,
    InputImage? preparedInputImage,
  }) async {
    final hasText = await _runGuarded<bool>(
      errorMessage: 'Realtime OCR gate failed',
      action: () async {
        final result = await _ocrGateService.evaluate(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: androidNv21Bytes,
          preparedInputImage: preparedInputImage,
        );
        if (result.hasText) {
          if (_overlayStateManager.documentStatus.value ==
                  _config.documentNoTextStatus ||
              _overlayStateManager.documentStatus.value ==
                  _config.documentScanningStatus) {
            _overlayStateManager.setDocumentSearchingState();
          }
        } else {
          _overlayStateManager.setDocumentNoTextState();
        }
        return result.hasText;
      },
    );
    _pipelineCoordinator.completeOcr(hasText: hasText);
  }

  Future<void> runFaceDetection(
    CameraImage frame, {
    required InputImageRotation rotation,
    required int nativeRotationDegrees,
    required int frameImageRotationDegrees,
    required bool needsMirrorCompensation,
    Uint8List? androidNv21Bytes,
    InputImage? preparedInputImage,
  }) async {
    await _runGuarded<void>(
      errorMessage: 'Realtime face detection failed',
      action: () async {
        final faces = await _faceDetectionService.detect(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: androidNv21Bytes,
          preparedInputImage: preparedInputImage,
        );
        final normalizedFaces = faces
            .map(
              (face) => _faceGeometryNormalizer.normalizeFaceRect(
                face.boundingBox,
                frame,
                nativeRotationDegrees: nativeRotationDegrees,
                needsMirrorCompensation: needsMirrorCompensation,
              ),
            )
            .whereType<Rect>()
            .toList(growable: false);
        final normalizedContours = faces
            .map(
              (face) => _faceGeometryNormalizer.normalizeFaceContour(
                face,
                frame,
                nativeRotationDegrees: nativeRotationDegrees,
                needsMirrorCompensation: needsMirrorCompensation,
              ),
            )
            .toList(growable: false);

        _overlayStateManager.applyFaceGeometry(
          nextFaceRects: normalizedFaces,
          nextFaceContours: normalizedContours,
        );

        if (normalizedFaces.isEmpty) {
          _overlayStateManager.setFaceNotFoundState();
          return;
        }

        _overlayStateManager.setFaceDetectedStatus(normalizedFaces.length);

        final now = DateTime.now();
        if (!_pipelineCoordinator.tryScheduleFacePanel(now)) return;

        final primaryFaceIndex = _faceGeometryNormalizer.selectPrimaryFaceIndex(
          normalizedFaces,
        );
        final primaryFaceRect = normalizedFaces[primaryFaceIndex];
        final primaryContour = primaryFaceIndex < normalizedContours.length
            ? normalizedContours[primaryFaceIndex]
            : const <Offset>[];
        if (!_overlayStateManager.shouldBuildFacePanelPreview(
          faceRect: primaryFaceRect,
          faceContour: primaryContour,
          now: now,
        )) {
          return;
        }

        final preview = await _previewBuilder.buildFacePreview(
          frame: frame,
          normalizedFaceRect: primaryFaceRect,
          normalizedContour: primaryContour,
          frameRotationDegrees: frameImageRotationDegrees,
          needsMirrorCompensation: needsMirrorCompensation,
        );
        if (preview != null) {
          _overlayStateManager.setFacePreviewBytes(preview);
          _overlayStateManager.rememberFacePreviewMotion(
            faceRect: primaryFaceRect,
            faceContour: primaryContour,
            now: now,
          );
        }
      },
    );
    _pipelineCoordinator.completeFace();
  }

  Future<void> runDocumentEdgeDetection(
    CameraImage frame, {
    required int nativeRotationDegrees,
    required int frameImageRotationDegrees,
    required bool isFrontCamera,
    required bool needsMirrorCompensation,
  }) async {
    await _runGuarded<void>(
      errorMessage: 'Realtime edge detection failed',
      action: () async {
        final corners = await _detectDocumentCorners(
          frame,
          nativeRotationDegrees: nativeRotationDegrees,
        );
        if (corners == null) {
          _overlayStateManager.setDocumentCorners(null);
          _overlayStateManager.setDocumentPreviewBytes(null);
          _overlayStateManager.resetDocumentPreviewMotionState();
          _overlayStateManager.setDocumentSearchingState();
          return;
        }

        _overlayStateManager.setDocumentCorners(corners);
        _overlayStateManager.setDocumentFoundState();

        final now = DateTime.now();
        if (!_pipelineCoordinator.tryScheduleDocumentPanel(now)) return;

        if (!_overlayStateManager.shouldBuildDocumentPanelPreview(
          corners: corners,
          now: now,
        )) {
          return;
        }

        final preview = await _previewBuilder.buildDocumentPreview(
          frame: frame,
          corners: corners,
          isFrontCamera: isFrontCamera,
          frameRotationDegrees: frameImageRotationDegrees,
          needsMirrorCompensation: needsMirrorCompensation,
        );
        if (preview != null) {
          _overlayStateManager.setDocumentPreviewBytes(preview);
          _overlayStateManager.rememberDocumentPreviewMotion(
            corners: corners,
            now: now,
          );
        }
      },
    );
    _pipelineCoordinator.completeEdge();
  }

  Future<T?> _runGuarded<T>({
    required String errorMessage,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (e, st) {
      Log.error(errorMessage, error: e, stackTrace: st, tag: _tag);
      return null;
    }
  }

  Future<NormalizedCorners?> _detectDocumentCorners(
    CameraImage frame, {
    required int nativeRotationDegrees,
  }) {
    if (frame.planes.isEmpty) return Future.value(null);

    if (_config.imageFormatGroup == ImageFormatGroup.bgra8888) {
      final plane = frame.planes.first;
      return _cornerDetectionService.detectCornersFromFrame(
        width: frame.width,
        height: frame.height,
        // If frame image is already preview-oriented, keep rotation at 0.
        rotation: _config.frameImageUsesNativeRotation
            ? nativeRotationDegrees
            : 0,
        bytes: plane.bytes,
        bytesPerRow: plane.bytesPerRow,
        format: 'bgra',
      );
    }

    if (frame.planes.length < 3) return Future.value(null);

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];

    return _cornerDetectionService.detectCornersFromFrame(
      width: frame.width,
      height: frame.height,
      rotation: nativeRotationDegrees,
      yBytes: yPlane.bytes,
      uBytes: uPlane.bytes,
      vBytes: vPlane.bytes,
      yRowStride: yPlane.bytesPerRow,
      uvRowStride: uPlane.bytesPerRow,
      uvPixelStride: uPlane.bytesPerPixel ?? 1,
      format: 'yuv420',
    );
  }

  /// Runs the full per-frame pipeline: schedules OCR/face/edge detection for
  /// this frame, shares the NV21/InputImage conversion across them, runs OCR +
  /// face concurrently, and records perf samples.
  Future<void> processFrame(
    CameraImage frame, {
    required InputImageRotation rotation,
    required int nativeRotationDegrees,
    required int frameImageRotationDegrees,
    required bool isFrontCamera,
    required bool needsMirrorCompensation,
  }) async {
    final frameWatch = PerfTrace.start();
    final now = DateTime.now();
    var nv21Resolved = false;
    Uint8List? sharedAndroidNv21;
    var inputImageResolved = false;
    InputImage? sharedInputImage;
    int? ocrMs;
    int? faceMs;
    int? edgeMs;
    final shouldRunOcr = _pipelineCoordinator.tryScheduleOcr(now);
    final shouldRunFace = _pipelineCoordinator.tryScheduleFace(now);

    Uint8List? resolveAndroidNv21() {
      if (_config.imageFormatGroup != ImageFormatGroup.yuv420) return null;
      if (!nv21Resolved) {
        sharedAndroidNv21 = cameraImageToNv21(frame);
        nv21Resolved = true;
      }
      return sharedAndroidNv21;
    }

    InputImage? resolveInputImage() {
      if (!inputImageResolved) {
        sharedInputImage = buildRealtimeInputImage(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: resolveAndroidNv21(),
        );
        inputImageResolved = true;
      }
      return sharedInputImage;
    }

    if (shouldRunOcr || shouldRunFace) {
      final androidNv21Bytes = resolveAndroidNv21();
      final preparedInputImage = resolveInputImage();
      Future<int?>? ocrFuture;
      Future<int?>? faceFuture;

      if (shouldRunOcr) {
        ocrFuture = () async {
          final ocrWatch = PerfTrace.start();
          await runOcrGate(
            frame,
            rotation: rotation,
            androidNv21Bytes: androidNv21Bytes,
            preparedInputImage: preparedInputImage,
          );
          return PerfTrace.stopMs(ocrWatch);
        }();
      }

      if (shouldRunFace) {
        faceFuture = () async {
          final faceWatch = PerfTrace.start();
          await runFaceDetection(
            frame,
            rotation: rotation,
            nativeRotationDegrees: nativeRotationDegrees,
            frameImageRotationDegrees: frameImageRotationDegrees,
            needsMirrorCompensation: needsMirrorCompensation,
            androidNv21Bytes: androidNv21Bytes,
            preparedInputImage: preparedInputImage,
          );
          return PerfTrace.stopMs(faceWatch);
        }();
      }

      if (ocrFuture != null && faceFuture != null) {
        final results = await Future.wait<int?>([ocrFuture, faceFuture]);
        ocrMs = results[0];
        faceMs = results[1];
      } else if (ocrFuture != null) {
        ocrMs = await ocrFuture;
      } else if (faceFuture != null) {
        faceMs = await faceFuture;
      }
    }

    if (_pipelineCoordinator.tryScheduleEdge(now)) {
      final edgeWatch = PerfTrace.start();
      await runDocumentEdgeDetection(
        frame,
        nativeRotationDegrees: nativeRotationDegrees,
        frameImageRotationDegrees: frameImageRotationDegrees,
        isFrontCamera: isFrontCamera,
        needsMirrorCompensation: needsMirrorCompensation,
      );
      edgeMs = PerfTrace.stopMs(edgeWatch);
      _perfTracker.recordSample(
        now: now,
        frameMs: PerfTrace.stopMs(frameWatch),
        ocrMs: ocrMs,
        faceMs: faceMs,
        edgeMs: edgeMs,
      );
      return;
    }

    if (!_pipelineCoordinator.hasOcrText) {
      _overlayStateManager.setDocumentNoTextState();
    }

    _perfTracker.recordSample(
      now: now,
      frameMs: PerfTrace.stopMs(frameWatch),
      ocrMs: ocrMs,
      faceMs: faceMs,
      edgeMs: edgeMs,
    );
  }
}
