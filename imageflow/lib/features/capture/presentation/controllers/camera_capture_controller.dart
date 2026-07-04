import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/coordinators/camera_route_lifecycle_controller.dart';
import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/log.dart';
import '../coordinators/camera_capture_session_lifecycle_helper.dart';
import '../models/camera_capture_config.dart';

class CameraCaptureController extends GetxController
    with WidgetsBindingObserver {
  CameraCaptureController({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    CameraCaptureConfig config = CameraCaptureConfig.defaults,
    CameraCaptureSessionLifecycleHelper? sessionLifecycleHelper,
    CameraRouteLifecycleController? routeLifecycleHelper,
    Duration startupDelay = AppConstants.routeTransitionSettleDelay,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _config = config,
       _startupDelay = startupDelay {
    _sessionLifecycleHelper =
        sessionLifecycleHelper ??
        CameraCaptureSessionLifecycleHelper(
          permissionService: _permissionService,
          cameraSessionService: _cameraSessionService,
          config: _config,
          isInitialized: isInitialized,
          hasCameraPermission: hasCameraPermission,
          canSwitchCamera: canSwitchCamera,
          isSwitchingCamera: isSwitchingCamera,
          flashMode: flashMode,
          failure: failure,
          isClosed: () => isClosed,
          enableInitGenerationGuard:
              AppConstants.enableCameraInitGenerationGuard,
        );

    _routeLifecycleHelper =
        routeLifecycleHelper ??
        CameraRouteLifecycleController(
          onPauseForLifecycle: _sessionLifecycleHelper.pauseForLifecycle,
          onResumeCameraSession: _sessionLifecycleHelper.resumeCameraSession,
          enableRouteAwareLifecycle:
              AppConstants.enableCaptureRouteAwareLifecycle,
          enableInactiveDebounce: AppConstants.enableCameraInactiveDebounce,
        );
  }

  final PermissionService _permissionService;
  final CameraSessionService _cameraSessionService;
  final CameraCaptureConfig _config;
  final Duration _startupDelay;

  late final CameraCaptureSessionLifecycleHelper _sessionLifecycleHelper;
  late final CameraRouteLifecycleController _routeLifecycleHelper;

  CameraController? get cameraController => _cameraSessionService.controller;

  final isInitialized = false.obs;
  final hasCameraPermission = false.obs;
  final isCapturing = false.obs;
  final isSwitchingCamera = false.obs;
  final canSwitchCamera = false.obs;
  final flashMode = FlashMode.off.obs;
  final failure = Rxn<Failure>();

  bool get isFrontCamera =>
      _cameraSessionService.description?.lensDirection ==
      CameraLensDirection.front;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Camera bring-up (native session + texture attach) is the heaviest
    // startup work in the app; defer it until the entrance transition settles
    // so the push animation doesn't stutter. The page already renders its
    // not-yet-initialized placeholder in the meantime.
    unawaited(_initAfterTransition());
  }

  Future<void> _initAfterTransition() async {
    if (_startupDelay > Duration.zero) {
      await Future<void>.delayed(_startupDelay);
      if (isClosed) return;
    }
    await _sessionLifecycleHelper.init();
  }

  Future<void> retryInit() {
    return _sessionLifecycleHelper.retryInit();
  }

  Future<void> openSystemSettings() async {
    await _sessionLifecycleHelper.shutdownCamera();
    if (Get.currentRoute == AppRoutes.capture) {
      Get.back<void>();
    }
    await _permissionService.openSettings();
  }

  Future<void> toggleFlashMode() async {
    final cam = cameraController;
    if (cam == null || !cam.value.isInitialized) return;

    final next = switch (flashMode.value) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.torch => FlashMode.off,
    };

    try {
      await cam.setFlashMode(next);
      flashMode.value = next;
    } on CameraException catch (e, st) {
      Log.error(
        'Flash mode change failed',
        error: e,
        stackTrace: st,
        tag: 'CameraCapture',
      );
      failure.value = CameraFailure('Flash mode failed: ${e.description}');
    } catch (e, st) {
      Log.error(
        'Flash mode change failed',
        error: e,
        stackTrace: st,
        tag: 'CameraCapture',
      );
      failure.value = CameraFailure('Flash mode failed: $e');
    }
  }

  Future<void> pauseForRoute() {
    return _routeLifecycleHelper.pauseForRoute();
  }

  Future<void> resumeFromRoute() {
    return _routeLifecycleHelper.resumeFromRoute();
  }

  Future<void> switchCamera() {
    return _sessionLifecycleHelper.switchCamera();
  }

  Future<void> capture() async {
    if (isCapturing.value) return;
    final cam = cameraController;
    if (cam == null || !cam.value.isInitialized) return;

    isCapturing.value = true;
    try {
      final file = await cam.takePicture();
      if (isClosed) return;
      await Get.offNamed(
        AppRoutes.processing,
        arguments: <String, dynamic>{
          'imagePath': file.path,
          'capturedWithFrontCamera': isFrontCamera,
        },
      );
    } on CameraException catch (e, st) {
      Log.error(
        'Capture failed',
        error: e,
        stackTrace: st,
        tag: 'CameraCapture',
      );
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: ${e.description}');
    } catch (e, st) {
      Log.error(
        'Capture failed',
        error: e,
        stackTrace: st,
        tag: 'CameraCapture',
      );
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: $e');
    } finally {
      if (!isClosed) isCapturing.value = false;
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) {
    return _routeLifecycleHelper.handleAppLifecycleState(state);
  }

  @override
  Future<void> onClose() async {
    WidgetsBinding.instance.removeObserver(this);
    _routeLifecycleHelper.dispose();
    await _sessionLifecycleHelper.shutdownCamera();
    super.onClose();
  }
}
