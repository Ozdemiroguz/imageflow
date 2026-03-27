import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/normalized_corners.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/native_corner_detection_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../services/realtime_face_detection_service.dart';
import '../../services/realtime_ocr_gate_service.dart';
import '../../services/realtime_preview_builder.dart';
import '../enums/realtime_native_rotation_strategy.dart';
import '../enums/realtime_preview_target.dart';
import '../../services/realtime_detection_pipeline_coordinator.dart';
import '../../services/realtime_stream_coordinator.dart';
import '../../services/realtime_frame_processor.dart';
import '../../services/realtime_overlay_state_store.dart';
import '../../services/realtime_route_lifecycle_coordinator.dart';
import '../../services/realtime_camera_session_coordinator.dart';
import '../models/capture_realtime_config.dart';
import '../models/realtime_overlay_state.dart';
import '../models/realtime_pipeline_coordinator.dart';

class RealtimeCameraController extends GetxController
    with WidgetsBindingObserver {
  RealtimeCameraController({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    required NativeCornerDetectionService cornerDetectionService,
    required RealtimeFaceDetectionService faceDetectionService,
    required RealtimeOcrGateService ocrGateService,
    required RealtimePreviewBuilder previewBuilder,
    CaptureRealtimeConfig config = CaptureRealtimeConfig.defaults,
    RealtimeOverlayState? overlayState,
    RealtimePipelineCoordinator? pipelineCoordinator,
    RealtimeOverlayStateStore? overlayStateManager,
    RealtimeDetectionPipelineCoordinator? detectionOrchestrator,
    RealtimeFrameProcessor? frameProcessor,
    RealtimeStreamCoordinator? framePipelineTrigger,
    RealtimeCameraSessionCoordinator? sessionLifecycleHelper,
    RealtimeRouteLifecycleCoordinator? routeLifecycleHelper,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _faceDetectionService = faceDetectionService,
       _ocrGateService = ocrGateService,
       _config = config {
    _overlayState = overlayState ?? RealtimeOverlayState(config: _config);
    _pipelineCoordinator =
        pipelineCoordinator ?? RealtimePipelineCoordinator(config: _config);
    _overlayStateManager =
        overlayStateManager ??
        RealtimeOverlayStateStore(
          config: _config,
          overlayState: _overlayState,
        );
    _detectionOrchestrator =
        detectionOrchestrator ??
        RealtimeDetectionPipelineCoordinator(
          config: _config,
          pipelineCoordinator: _pipelineCoordinator,
          overlayStateManager: _overlayStateManager,
          cornerDetectionService: cornerDetectionService,
          faceDetectionService: faceDetectionService,
          ocrGateService: ocrGateService,
          previewBuilder: previewBuilder,
        );
    _frameProcessor =
        frameProcessor ??
        RealtimeFrameProcessor(
          config: _config,
          pipelineCoordinator: _pipelineCoordinator,
          overlayStateManager: _overlayStateManager,
          detectionOrchestrator: _detectionOrchestrator,
        );

    _framePipelineTrigger =
        framePipelineTrigger ??
        RealtimeStreamCoordinator(
          config: _config,
          cameraSessionService: _cameraSessionService,
          frameProcessor: _frameProcessor,
          hasCameraPermission: hasCameraPermission,
          isStreaming: isStreaming,
          failure: failure,
          hasImageStreamSupport: () => hasImageStreamSupport,
          isClosed: () => isClosed,
          isCameraLifecycleBusy: () => _isCameraLifecycleBusy,
          isPausedByRoute: () => _isPausedByRoute,
          appLifecycleState: () => _appLifecycleState,
          syncFrameRotation: _syncFrameRotation,
          mlKitRotation: _mlKitRotation,
          nativeRotationDegrees: () => _nativeRotationDegrees,
          frameImageRotationDegrees: _frameImageRotationDegrees,
          isFrontCamera: () => isFrontCamera,
          needsMirrorCompensation: () => _needsMirrorCompensation,
        );

    _sessionLifecycleHelper =
        sessionLifecycleHelper ??
        RealtimeCameraSessionCoordinator(
          permissionService: _permissionService,
          cameraSessionService: _cameraSessionService,
          config: _config,
          isInitialized: isInitialized,
          hasCameraPermission: hasCameraPermission,
          isStreaming: isStreaming,
          canSwitchCamera: canSwitchCamera,
          isSwitchingCamera: isSwitchingCamera,
          failure: failure,
          isClosed: () => isClosed,
          isPausedByRoute: () => _isPausedByRoute,
          appLifecycleState: () => _appLifecycleState,
          resetRealtimeState: _resetRealtimeState,
          syncFrameRotation: _syncFrameRotation,
          resetRotationCache: _resetRotationCache,
          stopImageStream: _framePipelineTrigger.stopImageStream,
          resetFrameProcessingState:
              _framePipelineTrigger.resetFrameProcessingState,
          scheduleRealtimeStreamStart:
              _framePipelineTrigger.scheduleRealtimeStreamStart,
          cancelRealtimeStreamStart:
              _framePipelineTrigger.cancelRealtimeStreamStart,
          enableInitGenerationGuard:
              AppConstants.enableCameraInitGenerationGuard,
        );

    _routeLifecycleHelper =
        routeLifecycleHelper ??
        RealtimeRouteLifecycleCoordinator(
          onPauseForLifecycle: _sessionLifecycleHelper.pauseForLifecycle,
          onResumeCameraSession: _sessionLifecycleHelper.resumeCameraSession,
          enableRouteAwareLifecycle:
              AppConstants.enableRealtimeRouteAwareLifecycle,
          enableInactiveDebounce: AppConstants.enableCameraInactiveDebounce,
        );
  }

  final PermissionService _permissionService;
  final CameraSessionService _cameraSessionService;
  final RealtimeFaceDetectionService _faceDetectionService;
  final RealtimeOcrGateService _ocrGateService;
  final CaptureRealtimeConfig _config;

  late final RealtimeOverlayState _overlayState;
  late final RealtimePipelineCoordinator _pipelineCoordinator;
  late final RealtimeOverlayStateStore _overlayStateManager;
  late final RealtimeDetectionPipelineCoordinator _detectionOrchestrator;
  late final RealtimeFrameProcessor _frameProcessor;
  late final RealtimeStreamCoordinator _framePipelineTrigger;
  late final RealtimeCameraSessionCoordinator _sessionLifecycleHelper;
  late final RealtimeRouteLifecycleCoordinator _routeLifecycleHelper;

  CameraController? get cameraController => _cameraSessionService.controller;

  var _nativeRotationDegrees = 0;
  DeviceOrientation? _lastRotationDeviceOrientation;
  int? _lastRotationSensorOrientation;
  CameraLensDirection? _lastRotationLensDirection;

  bool get _isCameraLifecycleBusy => _sessionLifecycleHelper.isBusy;
  bool get _isPausedByRoute => _routeLifecycleHelper.isPausedByRoute;
  AppLifecycleState get _appLifecycleState =>
      _routeLifecycleHelper.appLifecycleState;

  final isInitialized = false.obs;
  final hasCameraPermission = false.obs;
  final isCapturing = false.obs;
  final isStreaming = false.obs;
  final isSwitchingCamera = false.obs;
  final canSwitchCamera = false.obs;
  final failure = Rxn<Failure>();

  RxList<Rect> get faceRects => _overlayStateManager.faceRects;
  RxList<List<Offset>> get faceContours => _overlayStateManager.faceContours;
  Rxn<NormalizedCorners> get documentCorners =>
      _overlayStateManager.documentCorners;
  Rxn<Uint8List> get facePreviewBytes => _overlayStateManager.facePreviewBytes;
  Rxn<Uint8List> get documentPreviewBytes =>
      _overlayStateManager.documentPreviewBytes;
  RxString get faceStatus => _overlayStateManager.faceStatus;
  RxString get documentStatus => _overlayStateManager.documentStatus;
  Rxn<RealtimePreviewTarget> get expandedPreviewTarget =>
      _overlayStateManager.expandedPreviewTarget;

  void toggleExpandedPreviewTarget(RealtimePreviewTarget target) {
    _overlayStateManager.toggleExpandedPreviewTarget(target);
  }

  void clearExpandedPreviewTarget() {
    _overlayStateManager.clearExpandedPreviewTarget();
  }

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
    await _sessionLifecycleHelper.shutdownCameraSession(resetRealtime: true);
    if (Get.isOverlaysOpen) {
      Get.back();
    } else if (Get.currentRoute == AppRoutes.realtime) {
      Get.back();
    }
    await _permissionService.openSettings();
  }

  bool get hasImageStreamSupport =>
      isInitialized.value && cameraController != null;

  Future<void> pauseForRoute() {
    return _routeLifecycleHelper.pauseForRoute();
  }

  Future<void> resumeFromRoute() {
    return _routeLifecycleHelper.resumeFromRoute();
  }

  Future<void> startImageStream(
    Future<void> Function(CameraImage image) onFrame,
  ) {
    return _framePipelineTrigger.startImageStream(onFrame);
  }

  Future<void> stopImageStream() {
    return _framePipelineTrigger.stopImageStream();
  }

  Future<void> capture() async {
    if (isCapturing.value) return;
    final cam = cameraController;
    if (cam == null || !cam.value.isInitialized) return;

    isCapturing.value = true;
    try {
      if (cam.value.isStreamingImages) {
        await stopImageStream();
      }
      final file = await cam.takePicture();
      if (isClosed) return;
      Get.back();
      await Get.toNamed(
        AppRoutes.processing,
        arguments: <String, dynamic>{
          'imagePath': file.path,
          'capturedWithFrontCamera': isFrontCamera,
        },
      );
    } on CameraException catch (e) {
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: ${e.description}');
    } catch (e) {
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: $e');
    } finally {
      if (!isClosed) isCapturing.value = false;
    }
  }

  Future<void> switchCamera() {
    return _sessionLifecycleHelper.switchCamera();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) {
    return _routeLifecycleHelper.handleAppLifecycleState(state);
  }

  @override
  Future<void> onClose() async {
    WidgetsBinding.instance.removeObserver(this);
    _routeLifecycleHelper.dispose();
    _framePipelineTrigger.dispose();
    await _sessionLifecycleHelper.shutdownCameraSession(resetRealtime: false);
    await _faceDetectionService.close();
    await _ocrGateService.close();
    super.onClose();
  }

  void _syncFrameRotation() {
    final camera = _cameraSessionService.description;
    final cam = cameraController;
    if (camera == null || cam == null || !cam.value.isInitialized) {
      _nativeRotationDegrees = 0;
      _resetRotationCache();
      return;
    }

    final sensorOrientation = camera.sensorOrientation;
    final deviceOrientation =
        cam.value.lockedCaptureOrientation ?? cam.value.deviceOrientation;
    final lensDirection = camera.lensDirection;
    if (_lastRotationDeviceOrientation == deviceOrientation &&
        _lastRotationSensorOrientation == sensorOrientation &&
        _lastRotationLensDirection == lensDirection) {
      return;
    }
    final deviceRotation = _deviceRotationDegrees(deviceOrientation);
    _lastRotationDeviceOrientation = deviceOrientation;
    _lastRotationSensorOrientation = sensorOrientation;
    _lastRotationLensDirection = lensDirection;

    switch (_config.nativeRotationStrategy) {
      case RealtimeNativeRotationStrategy.sensorAndDeviceByLens:
        _nativeRotationDegrees = lensDirection == CameraLensDirection.front
            ? (sensorOrientation + deviceRotation) % 360
            : (sensorOrientation - deviceRotation + 360) % 360;
      case RealtimeNativeRotationStrategy.sensorOnly:
        _nativeRotationDegrees = sensorOrientation % 360;
    }
  }

  void _resetRotationCache() {
    _lastRotationDeviceOrientation = null;
    _lastRotationSensorOrientation = null;
    _lastRotationLensDirection = null;
  }

  InputImageRotation _mlKitRotation() {
    return InputImageRotationValue.fromRawValue(_nativeRotationDegrees) ??
        InputImageRotation.rotation0deg;
  }

  int _frameImageRotationDegrees() {
    if (!_config.frameImageUsesNativeRotation) return 0;
    return _nativeRotationDegrees;
  }

  int _deviceRotationDegrees(DeviceOrientation orientation) {
    return switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
  }

  bool get isFrontCamera =>
      _cameraSessionService.description?.lensDirection ==
      CameraLensDirection.front;

  /// Preview is mirrored at widget level for front camera.
  /// Keep detection/crop in raw frame coordinates.
  bool get _needsMirrorCompensation => false;

  void _resetRealtimeState() {
    _pipelineCoordinator.reset();
    _overlayStateManager.resetAll();
  }
}
