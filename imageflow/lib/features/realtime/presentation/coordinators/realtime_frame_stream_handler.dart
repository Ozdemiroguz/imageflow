import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/camera_session_service.dart';
import '../models/capture_realtime_config.dart';
import '../../data/services/realtime_detection_pipeline.dart';
import 'realtime_frame_geometry_source.dart';

/// Presentation helper for camera stream start/stop and frame pipeline trigger.
/// This is a plain class, not a GetxService.
class RealtimeFrameStreamHandler {
  RealtimeFrameStreamHandler({
    required CaptureRealtimeConfig config,
    required CameraSessionService cameraSessionService,
    required RealtimeDetectionPipeline detectionPipeline,
    required RxBool hasCameraPermission,
    required RxBool isStreaming,
    required Rxn<Failure> failure,
    required bool Function() hasImageStreamSupport,
    required bool Function() isClosed,
    required bool Function() isCameraLifecycleBusy,
    required bool Function() isPausedByRoute,
    required AppLifecycleState Function() appLifecycleState,
    required RealtimeFrameGeometrySource frameGeometry,
  }) : _config = config,
       _cameraSessionService = cameraSessionService,
       _detectionPipeline = detectionPipeline,
       _hasCameraPermission = hasCameraPermission,
       _isStreaming = isStreaming,
       _failure = failure,
       _hasImageStreamSupport = hasImageStreamSupport,
       _isClosed = isClosed,
       _isCameraLifecycleBusy = isCameraLifecycleBusy,
       _isPausedByRoute = isPausedByRoute,
       _appLifecycleState = appLifecycleState,
       _frameGeometry = frameGeometry;

  final CaptureRealtimeConfig _config;
  final CameraSessionService _cameraSessionService;
  final RealtimeDetectionPipeline _detectionPipeline;
  final RxBool _hasCameraPermission;
  final RxBool _isStreaming;
  final Rxn<Failure> _failure;
  final bool Function() _hasImageStreamSupport;
  final bool Function() _isClosed;
  final bool Function() _isCameraLifecycleBusy;
  final bool Function() _isPausedByRoute;
  final AppLifecycleState Function() _appLifecycleState;
  final RealtimeFrameGeometrySource _frameGeometry;

  Timer? _realtimeStartTimer;
  var _isFrameProcessing = false;

  Future<void> startImageStream(
    Future<void> Function(CameraImage image) onFrame,
  ) async {
    if (!_hasImageStreamSupport() || _isStreaming.value) return;

    try {
      final started = await _cameraSessionService.startImageStream(onFrame);
      if (started) {
        _isStreaming.value = true;
      }
    } on CameraException catch (e) {
      _failure.value = CameraFailure('Image stream failed: ${e.description}');
    } catch (e) {
      _failure.value = CameraFailure('Image stream failed: $e');
    }
  }

  Future<void> stopImageStream() async {
    try {
      await _cameraSessionService.stopImageStream();
    } finally {
      _isStreaming.value = false;
    }
  }

  void scheduleRealtimeStreamStart() {
    cancelRealtimeStreamStart();
    final delay = _config.realtimeStreamStartDelay;
    _realtimeStartTimer = Timer(delay, () {
      unawaited(_startRealtimeStreamAfterDelay());
    });
  }

  void cancelRealtimeStreamStart() {
    _realtimeStartTimer?.cancel();
    _realtimeStartTimer = null;
  }

  void resetFrameProcessingState() {
    _isFrameProcessing = false;
  }

  Future<void> startRealtimeStreamIfReady() async {
    if (!_hasCameraPermission.value ||
        !_hasImageStreamSupport() ||
        _isStreaming.value) {
      return;
    }
    await startImageStream(handleRealtimeFrame);
  }

  Future<void> handleRealtimeFrame(CameraImage frame) async {
    if (_appLifecycleState() != AppLifecycleState.resumed ||
        _isPausedByRoute() ||
        _isCameraLifecycleBusy() ||
        _isFrameProcessing) {
      return;
    }

    _isFrameProcessing = true;
    try {
      _frameGeometry.sync();
      await _detectionPipeline.processFrame(
        frame,
        rotation: _frameGeometry.mlKitRotation,
        nativeRotationDegrees: _frameGeometry.nativeRotationDegrees,
        frameImageRotationDegrees: _frameGeometry.frameImageRotationDegrees,
        isFrontCamera: _frameGeometry.isFrontCamera,
        needsMirrorCompensation: _frameGeometry.needsMirrorCompensation,
      );
    } finally {
      _isFrameProcessing = false;
    }
  }

  void dispose() {
    cancelRealtimeStreamStart();
  }

  Future<void> _startRealtimeStreamAfterDelay() async {
    if (_isClosed() ||
        _isCameraLifecycleBusy() ||
        _isPausedByRoute() ||
        _appLifecycleState() != AppLifecycleState.resumed) {
      return;
    }
    await startRealtimeStreamIfReady();
  }
}
