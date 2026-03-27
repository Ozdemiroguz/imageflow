import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../services/camera_capture_actions_helper.dart';
import '../../services/camera_capture_route_lifecycle_helper.dart';
import '../../services/camera_capture_session_lifecycle_helper.dart';
import '../models/camera_capture_config.dart';

class CameraCaptureController extends GetxController
    with WidgetsBindingObserver {
  CameraCaptureController({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    CameraCaptureConfig config = CameraCaptureConfig.defaults,
    CameraCaptureSessionLifecycleHelper? sessionLifecycleHelper,
    CameraCaptureRouteLifecycleHelper? routeLifecycleHelper,
    CameraCaptureActionsHelper? actionsHelper,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _config = config {
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
        CameraCaptureRouteLifecycleHelper(
          onPauseForLifecycle: _sessionLifecycleHelper.pauseForLifecycle,
          onResumeCameraSession: _sessionLifecycleHelper.resumeCameraSession,
          enableRouteAwareLifecycle:
              AppConstants.enableCaptureRouteAwareLifecycle,
          enableInactiveDebounce: AppConstants.enableCameraInactiveDebounce,
        );

    _actionsHelper =
        actionsHelper ??
        CameraCaptureActionsHelper(
          cameraController: () => cameraController,
          flashMode: flashMode,
          isCapturing: isCapturing,
          failure: failure,
          isClosed: () => isClosed,
          isFrontCamera: () => isFrontCamera,
        );
  }

  final PermissionService _permissionService;
  final CameraSessionService _cameraSessionService;
  final CameraCaptureConfig _config;

  late final CameraCaptureSessionLifecycleHelper _sessionLifecycleHelper;
  late final CameraCaptureRouteLifecycleHelper _routeLifecycleHelper;
  late final CameraCaptureActionsHelper _actionsHelper;

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
  Future<void> onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> toggleFlashMode() {
    return _actionsHelper.toggleFlashMode();
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

  Future<void> capture() {
    return _actionsHelper.capture();
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
