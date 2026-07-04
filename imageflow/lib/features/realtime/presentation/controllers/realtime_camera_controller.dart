import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/detected_object_info.dart';
import '../../../../core/models/normalized_corners.dart';
import '../../../../core/platform/corner_detector.dart';
import '../../../../core/platform/object_detector.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/coordinators/camera_route_lifecycle_controller.dart';
import '../../../../core/services/camera_session_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/log.dart';
import '../coordinators/realtime_camera_session_manager.dart';
import '../../data/services/realtime_detection_pipeline.dart';
import '../../data/datasources/realtime_face_detection_service.dart';
import '../../data/datasources/realtime_ocr_gate_service.dart';
import '../state/realtime_overlay_state_store.dart';
import '../../data/services/realtime_preview_builder.dart';
import '../coordinators/realtime_frame_geometry_source.dart';
import '../coordinators/realtime_frame_stream_handler.dart';
import '../models/realtime_native_rotation_strategy.dart';
import '../enums/realtime_preview_target.dart';
import '../models/capture_realtime_config.dart';
import '../models/realtime_detection_modes.dart';
import '../models/realtime_overlay_state.dart';
import '../../data/services/realtime_detection_scheduler.dart';

class RealtimeCameraController extends GetxController
    with WidgetsBindingObserver {
  RealtimeCameraController({
    required PermissionService permissionService,
    required CameraSessionService cameraSessionService,
    required CornerDetector cornerDetectionService,
    required ObjectDetector objectDetectionService,
    required RealtimeFaceDetectionService faceDetectionService,
    required RealtimeOcrGateService ocrGateService,
    required RealtimePreviewBuilder previewBuilder,
    CaptureRealtimeConfig config = CaptureRealtimeConfig.defaults,
    RealtimeOverlayState? overlayState,
    RealtimeDetectionScheduler? scheduler,
    RealtimeOverlayStateStore? overlayStateManager,
    RealtimeDetectionPipeline? detectionPipeline,
    RealtimeFrameStreamHandler? streamHandler,
    RealtimeCameraSessionManager? sessionManager,
    CameraRouteLifecycleController? routeLifecycleController,
    Duration startupDelay = AppConstants.routeTransitionSettleDelay,
  }) : _permissionService = permissionService,
       _cameraSessionService = cameraSessionService,
       _faceDetectionService = faceDetectionService,
       _ocrGateService = ocrGateService,
       _config = config,
       _startupDelay = startupDelay {
    _overlayState = overlayState ?? RealtimeOverlayState(config: _config);
    _scheduler =
        scheduler ??
        RealtimeDetectionScheduler(
          faceInterval: _config.faceInterval,
          ocrInterval: _config.ocrInterval,
          edgeInterval: _config.edgeInterval,
          objectInterval: _config.objectInterval,
          facePanelInterval: _config.facePanelInterval,
          documentPanelInterval: _config.documentPanelInterval,
        );
    _overlayStateManager =
        overlayStateManager ??
        RealtimeOverlayStateStore(config: _config, overlayState: _overlayState);
    _detectionPipeline =
        detectionPipeline ??
        RealtimeDetectionPipeline(
          imageFormatGroup: _config.imageFormatGroup,
          frameImageUsesNativeRotation: _config.frameImageUsesNativeRotation,
          documentNoTextStatus: _config.documentNoTextStatus,
          documentScanningStatus: _config.documentScanningStatus,
          scheduler: _scheduler,
          output: _overlayStateManager,
          cornerDetectionService: cornerDetectionService,
          objectDetectionService: objectDetectionService,
          faceDetectionService: faceDetectionService,
          ocrGateService: ocrGateService,
          previewBuilder: previewBuilder,
        );
    _streamHandler =
        streamHandler ??
        RealtimeFrameStreamHandler(
          config: _config,
          cameraSessionService: _cameraSessionService,
          detectionPipeline: _detectionPipeline,
          hasCameraPermission: hasCameraPermission,
          isStreaming: isStreaming,
          failure: failure,
          hasImageStreamSupport: () => hasImageStreamSupport,
          isClosed: () => isClosed,
          isCameraLifecycleBusy: () => _isCameraLifecycleBusy,
          isPausedByRoute: () => _isPausedByRoute,
          appLifecycleState: () => _appLifecycleState,
          frameGeometry: RealtimeFrameGeometrySource(
            sync: _syncFrameRotation,
            mlKitRotation: _mlKitRotation,
            nativeRotationDegrees: () => _nativeRotationDegrees,
            frameImageRotationDegrees: _frameImageRotationDegrees,
            isFrontCamera: () => isFrontCamera,
            needsMirrorCompensation: () => _needsMirrorCompensation,
          ),
          detectionModes: () => detectionModes.value,
        );

    _sessionManager =
        sessionManager ??
        RealtimeCameraSessionManager(
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
          stopImageStream: _streamHandler.stopImageStream,
          resetFrameProcessingState: _streamHandler.resetFrameProcessingState,
          scheduleRealtimeStreamStart:
              _streamHandler.scheduleRealtimeStreamStart,
          cancelRealtimeStreamStart: _streamHandler.cancelRealtimeStreamStart,
          enableInitGenerationGuard:
              AppConstants.enableCameraInitGenerationGuard,
        );

    _routeLifecycleController =
        routeLifecycleController ??
        CameraRouteLifecycleController(
          onPauseForLifecycle: _sessionManager.pauseForLifecycle,
          onResumeCameraSession: _sessionManager.resumeCameraSession,
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
  final Duration _startupDelay;

  late final RealtimeOverlayState _overlayState;
  late final RealtimeDetectionScheduler _scheduler;
  late final RealtimeOverlayStateStore _overlayStateManager;
  late final RealtimeDetectionPipeline _detectionPipeline;
  late final RealtimeFrameStreamHandler _streamHandler;
  late final RealtimeCameraSessionManager _sessionManager;
  late final CameraRouteLifecycleController _routeLifecycleController;

  CameraController? get cameraController => _cameraSessionService.controller;

  var _nativeRotationDegrees = 0;
  DeviceOrientation? _lastRotationDeviceOrientation;
  int? _lastRotationSensorOrientation;
  CameraLensDirection? _lastRotationLensDirection;

  bool get _isCameraLifecycleBusy => _sessionManager.isBusy;
  bool get _isPausedByRoute => _routeLifecycleController.isPausedByRoute;
  AppLifecycleState get _appLifecycleState =>
      _routeLifecycleController.appLifecycleState;

  final isInitialized = false.obs;
  final hasCameraPermission = false.obs;
  final isCapturing = false.obs;
  final isStreaming = false.obs;
  final isSwitchingCamera = false.obs;
  final canSwitchCamera = false.obs;
  final failure = Rxn<Failure>();

  /// Which detectors are active. All on by default; the user toggles each
  /// independently. The frame stream handler reads this each frame.
  final detectionModes = const RealtimeDetectionModes().obs;

  void toggleFaceMode() => detectionModes.value = detectionModes.value.copyWith(
    face: !detectionModes.value.face,
  );

  void toggleDocumentMode() => detectionModes.value = detectionModes.value
      .copyWith(document: !detectionModes.value.document);

  void toggleObjectMode() => detectionModes.value = detectionModes.value
      .copyWith(object: !detectionModes.value.object);

  RxList<Rect> get faceRects => _overlayStateManager.faceRects;
  RxList<List<Offset>> get faceContours => _overlayStateManager.faceContours;
  RxList<DetectedObjectInfo> get detectedObjects =>
      _overlayStateManager.detectedObjects;
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
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Defer camera bring-up until the entrance transition settles so the push
    // animation doesn't stutter (same pattern as CameraCaptureController).
    unawaited(_initAfterTransition());
  }

  Future<void> _initAfterTransition() async {
    if (_startupDelay > Duration.zero) {
      await Future<void>.delayed(_startupDelay);
      if (isClosed) return;
    }
    await _sessionManager.init();
  }

  Future<void> retryInit() {
    return _sessionManager.retryInit();
  }

  Future<void> openSystemSettings() async {
    await _sessionManager.shutdownCameraSession(resetRealtime: true);
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
    return _routeLifecycleController.pauseForRoute();
  }

  Future<void> resumeFromRoute() {
    return _routeLifecycleController.resumeFromRoute();
  }

  Future<void> startImageStream(
    Future<void> Function(CameraImage image) onFrame,
  ) {
    return _streamHandler.startImageStream(onFrame);
  }

  Future<void> stopImageStream() {
    return _streamHandler.stopImageStream();
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
    } on CameraException catch (e, st) {
      Log.error(
        'Realtime capture failed',
        error: e,
        stackTrace: st,
        tag: 'RealtimeCamera',
      );
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: ${e.description}');
    } catch (e, st) {
      Log.error(
        'Realtime capture failed',
        error: e,
        stackTrace: st,
        tag: 'RealtimeCamera',
      );
      if (isClosed) return;
      failure.value = CameraFailure('Capture failed: $e');
    } finally {
      if (!isClosed) isCapturing.value = false;
    }
  }

  Future<void> switchCamera() {
    return _sessionManager.switchCamera();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) {
    return _routeLifecycleController.handleAppLifecycleState(state);
  }

  @override
  Future<void> onClose() async {
    WidgetsBinding.instance.removeObserver(this);
    _routeLifecycleController.dispose();
    _streamHandler.dispose();
    await _sessionManager.shutdownCameraSession(resetRealtime: false);
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
    _scheduler.reset();
    _overlayStateManager.resetAll();
  }
}
