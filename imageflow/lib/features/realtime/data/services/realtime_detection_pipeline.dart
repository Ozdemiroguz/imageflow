import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/models/detected_object_info.dart';
import '../../../../core/models/normalized_corners.dart';
import '../../../../core/platform/corner_detector.dart';
import '../../../../core/platform/object_detector.dart';
import '../../../../core/platform/camera_nv21_converter.dart';
import '../../../../core/utils/log.dart';
import '../../../../core/utils/perf_trace.dart';
import '../../../../core/platform/camera_input_image_factory.dart';
import 'detection_output_port.dart';
import 'realtime_detection_scheduler.dart';
import 'realtime_scene_gate.dart';
import '../datasources/realtime_face_detection_service.dart';
import 'realtime_face_geometry_normalizer.dart';
import 'realtime_frame_perf_tracker.dart';
import '../datasources/realtime_ocr_gate_service.dart';
import 'realtime_preview_builder.dart';

/// Per-frame detection pipeline: runs OCR, face, and document-edge detection
/// for a camera frame and writes results through [DetectionOutputPort].
///
/// Data layer, framework-free (plain class, not a GetxService).
class RealtimeDetectionPipeline {
  RealtimeDetectionPipeline({
    required this.imageFormatGroup,
    required this.frameImageUsesNativeRotation,
    required this.documentNoTextStatus,
    required this.documentScanningStatus,
    required RealtimeDetectionScheduler scheduler,
    required DetectionOutputPort output,
    required CornerDetector cornerDetectionService,
    required ObjectDetector objectDetectionService,
    required RealtimeFaceDetectionService faceDetectionService,
    required RealtimeOcrGateService ocrGateService,
    required RealtimePreviewBuilder previewBuilder,
    RealtimeFaceGeometryNormalizer? faceGeometryNormalizer,
    RealtimeFramePerfTracker? perfTracker,
    RealtimeSceneGate? sceneGate,
  }) : _scheduler = scheduler,
       _output = output,
       _cornerDetectionService = cornerDetectionService,
       _objectDetectionService = objectDetectionService,
       _faceDetectionService = faceDetectionService,
       _ocrGateService = ocrGateService,
       _previewBuilder = previewBuilder,
       _sceneGate = sceneGate ?? RealtimeSceneGate(),
       _faceGeometryNormalizer =
           faceGeometryNormalizer ??
           RealtimeFaceGeometryNormalizer(
             frameImageUsesNativeRotation: frameImageUsesNativeRotation,
           ),
       _perfTracker = perfTracker ?? RealtimeFramePerfTracker();

  static const _tag = 'RealtimeCamera';

  /// Camera frame plane layout — decides bgra vs yuv420 handling. Genuinely a
  /// data/camera concern, passed in from the platform preset.
  final ImageFormatGroup imageFormatGroup;

  /// Whether frames arrive already preview-oriented (native rotation applied).
  final bool frameImageUsesNativeRotation;

  // NOTE: these two are UI status strings the pipeline currently *reads back*
  // from the overlay store to decide transitions. That read-back is the
  // remaining data->presentation coupling; it will be inverted (data returns
  // results, presentation owns status) after realtime has a test safety net.
  // See docs/REALTIME_IDEAL_STRUCTURE.md.
  final String documentNoTextStatus;
  final String documentScanningStatus;

  final RealtimeDetectionScheduler _scheduler;
  final DetectionOutputPort _output;
  final CornerDetector _cornerDetectionService;
  final ObjectDetector _objectDetectionService;
  final RealtimeFaceDetectionService _faceDetectionService;
  final RealtimeOcrGateService _ocrGateService;
  final RealtimePreviewBuilder _previewBuilder;
  final RealtimeFaceGeometryNormalizer _faceGeometryNormalizer;
  final RealtimeFramePerfTracker _perfTracker;
  final RealtimeSceneGate _sceneGate;

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
          if (_output.documentStatusLabel == documentNoTextStatus ||
              _output.documentStatusLabel == documentScanningStatus) {
            _output.setDocumentSearchingState();
          }
        } else {
          _output.setDocumentNoTextState();
        }
        return result.hasText;
      },
    );
    _scheduler.endOcrDetection(hasText: hasText);
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

        _output.applyFaceGeometry(
          nextFaceRects: normalizedFaces,
          nextFaceContours: normalizedContours,
        );

        if (normalizedFaces.isEmpty) {
          _output.setFaceNotFoundState();
          return;
        }

        _output.setFaceDetectedStatus(normalizedFaces.length);

        final now = DateTime.now();
        if (!_scheduler.tryTakeFacePanelSlot(now)) return;

        final primaryFaceIndex = _faceGeometryNormalizer.selectPrimaryFaceIndex(
          normalizedFaces,
        );
        final primaryFaceRect = normalizedFaces[primaryFaceIndex];
        final primaryContour = primaryFaceIndex < normalizedContours.length
            ? normalizedContours[primaryFaceIndex]
            : const <Offset>[];
        if (!_output.shouldBuildFacePanelPreview(
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
          _output.setFacePreviewBytes(preview);
          _output.rememberFacePreviewMotion(
            faceRect: primaryFaceRect,
            faceContour: primaryContour,
            now: now,
          );
        }
      },
    );
    _scheduler.endFaceDetection();
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
          _output.setDocumentCorners(null);
          _output.setDocumentPreviewBytes(null);
          _output.resetDocumentPreviewMotionState();
          _output.setDocumentSearchingState();
          return;
        }

        _output.setDocumentCorners(corners);
        _output.setDocumentFoundState();

        final now = DateTime.now();
        if (!_scheduler.tryTakeDocumentPanelSlot(now)) return;

        if (!_output.shouldBuildDocumentPanelPreview(
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
          _output.setDocumentPreviewBytes(preview);
          _output.rememberDocumentPreviewMotion(corners: corners, now: now);
        }
      },
    );
    _scheduler.endEdgeDetection();
  }

  Future<void> runObjectDetection(
    CameraImage frame, {
    required int nativeRotationDegrees,
  }) async {
    await _runGuarded<void>(
      errorMessage: 'Realtime object detection failed',
      action: () async {
        final objects = await _detectObjects(
          frame,
          nativeRotationDegrees: nativeRotationDegrees,
        );
        _output.setDetectedObjects(objects);
      },
    );
    _scheduler.endObjectDetection();
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

    if (imageFormatGroup == ImageFormatGroup.bgra8888) {
      final plane = frame.planes.first;
      return _cornerDetectionService.detectCornersFromFrame(
        width: frame.width,
        height: frame.height,
        // If frame image is already preview-oriented, keep rotation at 0.
        rotation: frameImageUsesNativeRotation ? nativeRotationDegrees : 0,
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

  Future<List<DetectedObjectInfo>> _detectObjects(
    CameraImage frame, {
    required int nativeRotationDegrees,
  }) {
    if (frame.planes.isEmpty) return Future.value(const []);

    if (imageFormatGroup == ImageFormatGroup.bgra8888) {
      final plane = frame.planes.first;
      return _objectDetectionService.detectObjectsFromFrame(
        width: frame.width,
        height: frame.height,
        // If frame image is already preview-oriented, keep rotation at 0.
        rotation: frameImageUsesNativeRotation ? nativeRotationDegrees : 0,
        bytes: plane.bytes,
        bytesPerRow: plane.bytesPerRow,
        format: 'bgra',
      );
    }

    if (frame.planes.length < 3) return Future.value(const []);

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];

    return _objectDetectionService.detectObjectsFromFrame(
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
    int? objectMs;

    // Scene gate: skip ALL detection on a blank/flat frame (desk, wall). This
    // saves the CPU that was dropping the preview to a slideshow AND stops false
    // positives (e.g. "6 faces" on desk grain). The Y (luminance) plane is the
    // first plane for both YUV420 and BGRA layouts.
    if (frame.planes.isNotEmpty &&
        !_sceneGate.isInteresting(frame.planes.first.bytes)) {
      // Clear any stale overlays so old boxes don't linger over a blank scene.
      _output.setDetectedObjects(const []);
      _perfTracker.recordSample(
        now: now,
        frameMs: PerfTrace.stopMs(frameWatch),
      );
      return;
    }

    final shouldRunOcr = _scheduler.tryBeginOcrDetection(now);
    final shouldRunFace = _scheduler.tryBeginFaceDetection(now);
    final shouldRunObject = _scheduler.tryBeginObjectDetection(now);

    Uint8List? resolveAndroidNv21() {
      if (imageFormatGroup != ImageFormatGroup.yuv420) return null;
      if (!nv21Resolved) {
        sharedAndroidNv21 = cameraImageToNv21(frame);
        nv21Resolved = true;
      }
      return sharedAndroidNv21;
    }

    InputImage? resolveInputImage() {
      if (!inputImageResolved) {
        sharedInputImage = buildCameraInputImage(
          frame: frame,
          rotation: rotation,
          androidNv21Bytes: resolveAndroidNv21(),
        );
        inputImageResolved = true;
      }
      return sharedInputImage;
    }

    // OCR, face, and object detection all run concurrently for this frame.
    // OCR/face share the NV21/InputImage conversion; object detection sends the
    // raw camera planes straight to native, so it needs no shared conversion and
    // is scheduled here purely to overlap its native round-trip with the others.
    if (shouldRunOcr || shouldRunFace || shouldRunObject) {
      // Only resolve the shared conversion when OCR/face actually need it —
      // object detection alone must not pay for NV21/InputImage.
      final needsSharedConversion = shouldRunOcr || shouldRunFace;
      final androidNv21Bytes = needsSharedConversion
          ? resolveAndroidNv21()
          : null;
      final preparedInputImage = needsSharedConversion
          ? resolveInputImage()
          : null;
      Future<int?>? ocrFuture;
      Future<int?>? faceFuture;
      Future<int?>? objectFuture;

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

      if (shouldRunObject) {
        objectFuture = () async {
          final objectWatch = PerfTrace.start();
          await runObjectDetection(
            frame,
            nativeRotationDegrees: nativeRotationDegrees,
          );
          return PerfTrace.stopMs(objectWatch);
        }();
      }

      final results = await Future.wait<int?>([
        ?ocrFuture,
        ?faceFuture,
        ?objectFuture,
      ]);
      var i = 0;
      if (ocrFuture != null) ocrMs = results[i++];
      if (faceFuture != null) faceMs = results[i++];
      if (objectFuture != null) objectMs = results[i++];
    }

    if (_scheduler.tryBeginEdgeDetection(now)) {
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
        objectMs: objectMs,
      );
      return;
    }

    if (!_scheduler.hasOcrText) {
      _output.setDocumentNoTextState();
    }

    _perfTracker.recordSample(
      now: now,
      frameMs: PerfTrace.stopMs(frameWatch),
      ocrMs: ocrMs,
      faceMs: faceMs,
      edgeMs: edgeMs,
      objectMs: objectMs,
    );
  }
}
