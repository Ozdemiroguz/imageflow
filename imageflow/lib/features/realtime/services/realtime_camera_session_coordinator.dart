import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/camera_session_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/camera_lifecycle_guard.dart';
import '../presentation/models/capture_realtime_config.dart';

/// Presentation helper for camera session lifecycle operations in realtime flow.
/// This is a plain class, not a GetxService.
class RealtimeCameraSessionCoordinator {
  RealtimeCameraSessionCoordinator({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    required CaptureRealtimeConfig config,
    required RxBool isInitialized,
    required RxBool hasCameraPermission,
    required RxBool isStreaming,
    required RxBool canSwitchCamera,
    required RxBool isSwitchingCamera,
    required Rxn<Failure> failure,
    required bool Function() isClosed,
    required bool Function() isPausedByRoute,
    required AppLifecycleState Function() appLifecycleState,
    required void Function() resetRealtimeState,
    required void Function() syncFrameRotation,
    required void Function() resetRotationCache,
    required Future<void> Function() stopImageStream,
    required void Function() resetFrameProcessingState,
    required void Function() scheduleRealtimeStreamStart,
    required void Function() cancelRealtimeStreamStart,
    this.enableInitGenerationGuard =
        AppConstants.enableCameraInitGenerationGuard,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _config = config,
       _isInitialized = isInitialized,
       _hasCameraPermission = hasCameraPermission,
       _isStreaming = isStreaming,
       _canSwitchCamera = canSwitchCamera,
       _isSwitchingCamera = isSwitchingCamera,
       _failure = failure,
       _isClosed = isClosed,
       _isPausedByRoute = isPausedByRoute,
       _appLifecycleState = appLifecycleState,
       _resetRealtimeState = resetRealtimeState,
       _syncFrameRotation = syncFrameRotation,
       _resetRotationCache = resetRotationCache,
       _stopImageStream = stopImageStream,
       _resetFrameProcessingState = resetFrameProcessingState,
       _scheduleRealtimeStreamStart = scheduleRealtimeStreamStart,
       _cancelRealtimeStreamStart = cancelRealtimeStreamStart;

  final PermissionService _permissionService;
  final CameraSessionService _cameraSessionService;
  final CaptureRealtimeConfig _config;
  final RxBool _isInitialized;
  final RxBool _hasCameraPermission;
  final RxBool _isStreaming;
  final RxBool _canSwitchCamera;
  final RxBool _isSwitchingCamera;
  final Rxn<Failure> _failure;
  final bool Function() _isClosed;
  final bool Function() _isPausedByRoute;
  final AppLifecycleState Function() _appLifecycleState;
  final void Function() _resetRealtimeState;
  final void Function() _syncFrameRotation;
  final void Function() _resetRotationCache;
  final Future<void> Function() _stopImageStream;
  final void Function() _resetFrameProcessingState;
  final void Function() _scheduleRealtimeStreamStart;
  final void Function() _cancelRealtimeStreamStart;
  final bool enableInitGenerationGuard;
  final _lifecycleGuard = CameraLifecycleGuard();

  bool get isBusy => _lifecycleGuard.isBusy;

  Future<void> init() async {
    if (!_beginCameraLifecycleOp()) return;
    try {
      await _initializeCamera(requestIfNeeded: true);
    } finally {
      _endCameraLifecycleOp();
    }
  }

  Future<void> retryInit() async {
    if (!_beginCameraLifecycleOp()) return;
    try {
      final permissionGranted = await _ensureCameraPermission(
        requestIfNeeded: true,
      );
      if (!permissionGranted) {
        await shutdownCameraSession(resetRealtime: true);
        return;
      }

      await shutdownCameraSession(resetRealtime: true);
      await _initializeCamera(requestIfNeeded: true);
    } finally {
      _endCameraLifecycleOp();
    }
  }

  Future<void> switchCamera() async {
    if (!_canSwitchCamera.value || _isSwitchingCamera.value) return;
    final next = _cameraSessionService.resolveNextCamera();
    if (next == null) return;
    if (!_beginCameraLifecycleOp()) return;

    _isSwitchingCamera.value = true;
    _failure.value = null;
    try {
      _isInitialized.value = false;
      _cancelRealtimeStreamStart();
      await _stopImageStream();
      await _cameraSessionService.disposeControllerSafely();
      _resetRealtimeState();
      await _activateCamera(next);
    } on CameraException catch (e) {
      _failure.value = CameraFailure('Camera switch failed: ${e.description}');
    } catch (e) {
      _failure.value = CameraFailure('Camera switch failed: $e');
    } finally {
      _isSwitchingCamera.value = false;
      _endCameraLifecycleOp();
    }
  }

  Future<void> pauseForLifecycle() async {
    if (!_beginCameraLifecycleOp()) return;
    try {
      await shutdownCameraSession(resetRealtime: true);
    } finally {
      _endCameraLifecycleOp();
    }
  }

  Future<void> resumeCameraSession() async {
    if (!_beginCameraLifecycleOp()) return;

    try {
      final permissionGranted = await _ensureCameraPermission(
        requestIfNeeded: false,
      );
      if (!permissionGranted) {
        await shutdownCameraSession(resetRealtime: true);
        return;
      }

      final cam = _cameraSessionService.controller;
      if (cam != null && cam.value.isInitialized) {
        if (!_isStreaming.value) {
          _scheduleRealtimeStreamStart();
        }
        return;
      }

      final lastDescription = _cameraSessionService.description;
      if (lastDescription == null) {
        await _initializeCamera(requestIfNeeded: false);
        return;
      }

      try {
        await _activateCamera(lastDescription);
      } on CameraException catch (e) {
        _failure.value = CameraFailure(
          'Camera resume failed: ${e.description}',
        );
      } catch (e) {
        _failure.value = CameraFailure('Camera resume failed: $e');
      }
    } finally {
      _endCameraLifecycleOp();
    }
  }

  Future<void> shutdownCameraSession({required bool resetRealtime}) async {
    _invalidateInitGeneration();
    _isInitialized.value = false;
    _resetFrameProcessingState();
    _resetRotationCache();
    _cancelRealtimeStreamStart();
    await _stopImageStream();
    await Future<void>.delayed(Duration.zero);
    await _cameraSessionService.disposeControllerSafely();
    if (resetRealtime) {
      _resetRealtimeState();
    }
  }

  Future<bool> ensureCameraPermission({required bool requestIfNeeded}) {
    return _ensureCameraPermission(requestIfNeeded: requestIfNeeded);
  }

  Future<void> _initializeCamera({required bool requestIfNeeded}) async {
    final initGeneration = _nextInitGeneration();
    _isInitialized.value = false;
    final permissionGranted = await _ensureCameraPermission(
      requestIfNeeded: requestIfNeeded,
    );
    if (!_isCurrentInitGeneration(initGeneration) || _isClosed()) {
      return;
    }
    if (!permissionGranted) {
      await shutdownCameraSession(resetRealtime: true);
      return;
    }

    _failure.value = null;
    _resetRealtimeState();

    try {
      await _cameraSessionService.initializeAndActivatePreferred(
        resolutionPreset: _config.resolutionPreset,
        imageFormatGroup: _config.imageFormatGroup,
        enableAudio: false,
      );
      if (_isClosed() || !_isCurrentInitGeneration(initGeneration)) {
        await _cameraSessionService.disposeControllerSafely();
        return;
      }
      _canSwitchCamera.value = _cameraSessionService.canSwitchCamera;
      _syncFrameRotation();
      _isInitialized.value = true;
      if (_appLifecycleState() == AppLifecycleState.resumed &&
          !_isPausedByRoute()) {
        _scheduleRealtimeStreamStart();
      } else {
        await _cameraSessionService.disposeControllerSafely();
        _isInitialized.value = false;
      }
    } on CameraException catch (e) {
      if (!_isCurrentInitGeneration(initGeneration) || _isClosed()) {
        return;
      }
      if (e.code == 'no-camera') {
        _failure.value = const CameraFailure('No camera found on this device.');
      } else {
        _failure.value = CameraFailure(
          'Camera initialization failed: ${e.description}',
        );
      }
    } catch (e) {
      if (!_isCurrentInitGeneration(initGeneration) || _isClosed()) {
        return;
      }
      _failure.value = CameraFailure('Unexpected camera error: $e');
    }
  }

  Future<void> _activateCamera(CameraDescription camera) async {
    final initGeneration = _nextInitGeneration();
    final permissionGranted = await _ensureCameraPermission(
      requestIfNeeded: false,
    );
    if (!_isCurrentInitGeneration(initGeneration) || _isClosed()) {
      return;
    }
    if (!permissionGranted) {
      await shutdownCameraSession(resetRealtime: true);
      return;
    }

    await _cameraSessionService.activateCamera(
      camera,
      resolutionPreset: _config.resolutionPreset,
      imageFormatGroup: _config.imageFormatGroup,
      enableAudio: false,
    );

    if (_isClosed() || !_isCurrentInitGeneration(initGeneration)) {
      await _cameraSessionService.disposeControllerSafely();
      return;
    }

    _canSwitchCamera.value = _cameraSessionService.canSwitchCamera;
    _syncFrameRotation();
    _isInitialized.value = true;
    if (_appLifecycleState() == AppLifecycleState.resumed &&
        !_isPausedByRoute()) {
      _scheduleRealtimeStreamStart();
    } else {
      await _cameraSessionService.disposeControllerSafely();
      _isInitialized.value = false;
    }
  }

  Future<bool> _ensureCameraPermission({required bool requestIfNeeded}) async {
    var granted = await _permissionService.isCameraGranted;
    if (!granted && requestIfNeeded) {
      granted = await _permissionService.requestCamera();
    }

    _hasCameraPermission.value = granted;
    if (!granted) {
      _failure.value = const PermissionFailure(
        'Camera access is required. Please enable it in Settings.',
      );
    } else if (_failure.value is PermissionFailure) {
      _failure.value = null;
    }
    return granted;
  }

  bool _beginCameraLifecycleOp() {
    return _lifecycleGuard.begin();
  }

  void _endCameraLifecycleOp() {
    _lifecycleGuard.end();
  }

  int _nextInitGeneration() {
    return _lifecycleGuard.nextGeneration(enabled: enableInitGenerationGuard);
  }

  void _invalidateInitGeneration() {
    _lifecycleGuard.invalidate(enabled: enableInitGenerationGuard);
  }

  bool _isCurrentInitGeneration(int generation) {
    return _lifecycleGuard.isCurrent(
      generation,
      enabled: enableInitGenerationGuard,
    );
  }
}
