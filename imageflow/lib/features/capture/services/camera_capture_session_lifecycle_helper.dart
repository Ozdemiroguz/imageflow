import 'package:camera/camera.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/camera_session_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/camera_lifecycle_guard.dart';
import '../presentation/models/camera_capture_config.dart';

/// Presentation helper for camera session lifecycle operations in capture flow.
/// This is a plain class, not a GetxService.
class CameraCaptureSessionLifecycleHelper {
  CameraCaptureSessionLifecycleHelper({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    required CameraCaptureConfig config,
    required RxBool isInitialized,
    required RxBool hasCameraPermission,
    required RxBool canSwitchCamera,
    required RxBool isSwitchingCamera,
    required Rx<FlashMode> flashMode,
    required Rxn<Failure> failure,
    required bool Function() isClosed,
    this.enableInitGenerationGuard =
        AppConstants.enableCameraInitGenerationGuard,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _config = config,
       _isInitialized = isInitialized,
       _hasCameraPermission = hasCameraPermission,
       _canSwitchCamera = canSwitchCamera,
       _isSwitchingCamera = isSwitchingCamera,
       _flashMode = flashMode,
       _failure = failure,
       _isClosed = isClosed;

  final PermissionService _permissionService;
  final CameraSessionService _cameraSessionService;
  final CameraCaptureConfig _config;
  final RxBool _isInitialized;
  final RxBool _hasCameraPermission;
  final RxBool _canSwitchCamera;
  final RxBool _isSwitchingCamera;
  final Rx<FlashMode> _flashMode;
  final Rxn<Failure> _failure;
  final bool Function() _isClosed;
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
      await shutdownCamera();
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
      await _cameraSessionService.disposeControllerSafely();
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
      await shutdownCamera();
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
        await shutdownCamera();
        return;
      }

      final cam = _cameraSessionService.controller;
      if (cam != null && cam.value.isInitialized) {
        _isInitialized.value = true;
        await _syncFlashModeFromController();
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

  Future<void> shutdownCamera() async {
    _invalidateInitGeneration();
    _isInitialized.value = false;
    _canSwitchCamera.value = false;
    _flashMode.value = FlashMode.off;
    await _cameraSessionService.disposeControllerSafely();
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
      await shutdownCamera();
      return;
    }

    _failure.value = null;
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
      _isInitialized.value = true;
      await _syncFlashModeFromController();
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
      await shutdownCamera();
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
    _isInitialized.value = true;
    await _syncFlashModeFromController();
  }

  Future<void> _syncFlashModeFromController() async {
    final cam = _cameraSessionService.controller;
    if (cam == null || !cam.value.isInitialized) {
      _flashMode.value = FlashMode.off;
      return;
    }
    _flashMode.value = cam.value.flashMode;
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
