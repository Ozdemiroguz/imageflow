import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/utils/android_nv21.dart';
import '../../../core/utils/perf_trace.dart';
import '../../../core/utils/realtime_input_image_factory.dart';
import '../presentation/models/capture_realtime_config.dart';
import '../presentation/models/realtime_pipeline_coordinator.dart';
import 'realtime_detection_pipeline_coordinator.dart';
import 'realtime_frame_perf_tracker.dart';
import 'realtime_overlay_state_store.dart';

/// Presentation helper that runs the realtime frame pipeline.
/// This is a plain class, not a GetxService.
class RealtimeFrameProcessor {
  RealtimeFrameProcessor({
    required CaptureRealtimeConfig config,
    required RealtimePipelineCoordinator pipelineCoordinator,
    required RealtimeOverlayStateStore overlayStateManager,
    required RealtimeDetectionPipelineCoordinator detectionOrchestrator,
  }) : _config = config,
       _pipelineCoordinator = pipelineCoordinator,
       _overlayStateManager = overlayStateManager,
       _detectionOrchestrator = detectionOrchestrator;

  final CaptureRealtimeConfig _config;
  final RealtimePipelineCoordinator _pipelineCoordinator;
  final RealtimeOverlayStateStore _overlayStateManager;
  final RealtimeDetectionPipelineCoordinator _detectionOrchestrator;
  final RealtimeFramePerfTracker _perfTracker = RealtimeFramePerfTracker();

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
          await _detectionOrchestrator.runOcrGate(
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
          await _detectionOrchestrator.runFaceDetection(
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
      await _detectionOrchestrator.runDocumentEdgeDetection(
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
